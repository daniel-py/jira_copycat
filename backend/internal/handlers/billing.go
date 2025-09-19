package handlers

import (
	"database/sql"
	"net/http"

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
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create subscription"})
		return
	}

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
	// This endpoint would be called by Paystack to notify about payment status changes
	// You would implement webhook verification and handle different event types
	// For now, we'll just return a success response
	
	c.JSON(http.StatusOK, gin.H{"status": "success"})
}
