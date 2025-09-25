package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"jira-copycat-backend/internal/models"
	"jira-copycat-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type BillingHandler struct {
	db *sql.DB
}

func NewBillingHandler(db *sql.DB) *BillingHandler {
	return &BillingHandler{db: db}
}

func (h *BillingHandler) GetPlans(c *gin.Context) {
	paystackService := services.NewPaystackService()
	plans := paystackService.GetSubscriptionPlans()
	
	c.JSON(http.StatusOK, gin.H{"plans": plans})
}

func (h *BillingHandler) InitializeSubscription(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req models.SubscriptionCreate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user already has any subscription (active or pending)
	existingSubscription, err := services.GetUserAnySubscription(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check existing subscription"})
		return
	}
	
	if existingSubscription != nil {
		var message string
		if existingSubscription.Status == "active" {
			message = "You already have an active subscription. Please cancel your current subscription before subscribing to a new plan."
		} else {
			message = "You have a pending subscription. Please complete or cancel your current subscription before subscribing to a new plan."
		}
		
		c.JSON(http.StatusConflict, gin.H{
			"error": message,
			"current_plan": existingSubscription.Plan,
			"status": existingSubscription.Status,
		})
		return
	}

	// Get user details
	user, err := services.GetUserByID(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Initialize Paystack transaction
	paystackService := services.NewPaystackService()
	paystackResp, err := paystackService.InitializeTransaction(user.Email, req.Amount, req.Plan)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to initialize payment"})
		return
	}

	if !paystackResp.Status {
		c.JSON(http.StatusBadRequest, gin.H{"error": paystackResp.Message})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"reference": paystackResp.Data.Reference,
		"access_code": paystackResp.Data.AccessCode,
		"authorization_url": paystackResp.Data.AuthorizationURL,
	})
}

func (h *BillingHandler) VerifySubscription(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	reference := c.Query("reference")
	if reference == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Reference is required"})
		return
	}

	// Verify with Paystack
	paystackService := services.NewPaystackService()
	paystackResp, err := paystackService.VerifyTransaction(reference)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify payment"})
		return
	}

	if !paystackResp.Status || paystackResp.Data.Status != "success" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Payment verification failed"})
		return
	}

	// Determine plan from metadata or amount
	plan := paystackResp.Data.Metadata.Plan
	if plan == "" {
		switch paystackResp.Data.Amount {
		case 500000:
			plan = "basic"
		case 1500000:
			plan = "pro"
		case 5000000:
			plan = "enterprise"
		default:
			plan = "basic"
		}
	}

    // Create subscription honoring selected plan
    subscription, err := services.CreateSubscription(
		h.db,
		userID.(uuid.UUID),
		paystackResp.Data.Reference,
        plan,
        paystackResp.Data.Amount,
        paystackResp.Data.Authorization.AuthorizationCode,
        paystackResp.Data.Customer.CustomerCode,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create subscription"})
		return
	}

	// Record payment for this verification (in case webhook didn't fire or failed)
	paidAt := time.Now()
	_ = services.RecordPayment(h.db, userID.(uuid.UUID), &subscription.ID, paystackResp.Data.Reference, paystackResp.Data.Amount, paystackResp.Data.Currency, "success", paystackResp.Data.Channel, &paidAt)

	c.JSON(http.StatusOK, gin.H{
		"message": "Subscription created successfully",
		"subscription": subscription,
	})
}

func (h *BillingHandler) GetSubscriptionStatus(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	subscription, err := services.GetUserSubscription(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if subscription == nil {
		c.JSON(http.StatusOK, gin.H{
			"has_subscription": false,
			"subscription": nil,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"has_subscription": true,
		"subscription": subscription,
	})
}

func (h *BillingHandler) Webhook(c *gin.Context) {
    // Process Paystack webhook: store payment, capture auth/customer codes, and update subscription
    var payload map[string]interface{}
    if err := c.BindJSON(&payload); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
        return
    }

    event, _ := payload["event"].(string)
    data, _ := payload["data"].(map[string]interface{})
    if event == "charge.success" && data != nil {
        reference, _ := data["reference"].(string)
        amountFloat, _ := data["amount"].(float64)
        amount := int(amountFloat)
        currency, _ := data["currency"].(string)
        status, _ := data["status"].(string)
        channel, _ := data["channel"].(string)

        customer, _ := data["customer"].(map[string]interface{})
        email, _ := customer["email"].(string)
        customerCode, _ := customer["customer_code"].(string)

        authorization, _ := data["authorization"].(map[string]interface{})
        authCode, _ := authorization["authorization_code"].(string)

        // Map email to user
        // Note: We only have GetUserByID; implement a simple lookup for user by email here
        var userID uuid.UUID
        err := h.db.QueryRow("SELECT id FROM users WHERE LOWER(email) = LOWER($1)", email).Scan(&userID)
        if err == nil {
            // Find active subscription for user
            sub, _ := services.GetUserSubscription(h.db, userID)
            var subID *uuid.UUID
            if sub != nil {
                subID = &sub.ID
                // Update subscription with latest auth/customer code and set next billing
                _, _ = h.db.Exec(`UPDATE subscriptions SET authorization_code=$1, customer_code=$2, paystack_reference=$3, next_billing_date=GREATEST(next_billing_date, NOW()) + INTERVAL '1 month', updated_at=$4 WHERE id=$5`,
                    authCode, customerCode, reference, time.Now(), sub.ID)
            }

            // Record payment
            var paidAt *time.Time
            if tStr, ok := data["paidAt"].(string); ok && tStr != "" {
                if t, err := time.Parse(time.RFC3339, tStr); err == nil {
                    paidAt = &t
                }
            }
            _ = services.RecordPayment(h.db, userID, subID, reference, amount, currency, status, channel, paidAt)
        }
    }

    c.JSON(http.StatusOK, gin.H{"status": "success"})
}

func (h *BillingHandler) GetPaymentHistory(c *gin.Context) {
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
        return
    }

    payments, err := services.GetPaymentHistory(h.db, userID.(uuid.UUID))
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, gin.H{"payments": payments})
}

func (h *BillingHandler) Get2FAStatus(c *gin.Context) {
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
        return
    }

    subscription, err := services.GetUserSubscription(h.db, userID.(uuid.UUID))
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    if subscription == nil || subscription.Status != "pending_2fa" {
        c.JSON(http.StatusOK, gin.H{
            "requires_2fa": false,
            "message": "No 2FA required",
        })
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "requires_2fa": true,
        "authorization_url": subscription.Pending2FAURL,
        "reference": subscription.Pending2FAReference,
        "created_at": subscription.Pending2FACreatedAt,
        "message": "Please complete 2FA to renew your subscription",
    })
}

func (h *BillingHandler) Get2FAURL(c *gin.Context) {
    userID, exists := c.Get("user_id")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
        return
    }

    subscription, err := services.GetUserSubscription(h.db, userID.(uuid.UUID))
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    if subscription == nil || subscription.Status != "pending_2fa" {
        c.JSON(http.StatusBadRequest, gin.H{"error": "No pending 2FA found"})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "authorization_url": subscription.Pending2FAURL,
        "reference": subscription.Pending2FAReference,
    })
}
