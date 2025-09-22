package services

import (
	"database/sql"
	"fmt"
	"time"

	"jira-copycat-backend/internal/models"

	"github.com/google/uuid"
)

func CreateSubscription(db *sql.DB, userID uuid.UUID, paystackRef, plan string, amount int, authCode string, customerCode string) (*models.Subscription, error) {
	// Calculate subscription dates
	startDate := time.Now()
	var endDate time.Time
	
	switch plan {
	case "basic":
		endDate = startDate.AddDate(0, 1, 0) // 1 month
	case "pro":
		endDate = startDate.AddDate(0, 1, 0) // 1 month
	case "enterprise":
		endDate = startDate.AddDate(0, 1, 0) // 1 month
	default:
		return nil, fmt.Errorf("invalid plan")
	}

    nextBilling := endDate

    subscription := &models.Subscription{
		ID:                uuid.New(),
		UserID:            userID,
		PaystackReference: paystackRef,
		Plan:              plan,
		Status:            "active",
		Amount:            amount,
		Currency:          "NGN",
        AuthorizationCode: authCode,
        CustomerCode:      customerCode,
		StartDate:         startDate,
        EndDate:           endDate,
        NextBillingDate:   nextBilling,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}

    _, err := db.Exec(`
        INSERT INTO subscriptions (id, user_id, paystack_reference, plan, status, amount, currency, authorization_code, customer_code, start_date, end_date, next_billing_date, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
		subscription.ID, subscription.UserID, subscription.PaystackReference, subscription.Plan,
        subscription.Status, subscription.Amount, subscription.Currency, subscription.AuthorizationCode, subscription.CustomerCode, subscription.StartDate,
        subscription.EndDate, subscription.NextBillingDate, subscription.CreatedAt, subscription.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return subscription, nil
}

func GetUserSubscription(db *sql.DB, userID uuid.UUID) (*models.Subscription, error) {
	var subscription models.Subscription
	err := db.QueryRow(`
        SELECT id, user_id, paystack_reference, plan, status, amount, currency, authorization_code, customer_code, start_date, end_date, next_billing_date, created_at, updated_at
		FROM subscriptions WHERE user_id = $1 AND status = 'active'
		ORDER BY created_at DESC LIMIT 1`,
		userID).Scan(
        &subscription.ID, &subscription.UserID, &subscription.PaystackReference, &subscription.Plan,
        &subscription.Status, &subscription.Amount, &subscription.Currency, &subscription.AuthorizationCode, &subscription.CustomerCode, &subscription.StartDate,
        &subscription.EndDate, &subscription.NextBillingDate, &subscription.CreatedAt, &subscription.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No active subscription
		}
		return nil, err
	}

	return &subscription, nil
}

func GetUserAnySubscription(db *sql.DB, userID uuid.UUID) (*models.Subscription, error) {
	var subscription models.Subscription
	err := db.QueryRow(`
        SELECT id, user_id, paystack_reference, plan, status, amount, currency, authorization_code, customer_code, start_date, end_date, next_billing_date, created_at, updated_at
		FROM subscriptions WHERE user_id = $1 AND status IN ('active', 'pending')
		ORDER BY created_at DESC LIMIT 1`,
		userID).Scan(
        &subscription.ID, &subscription.UserID, &subscription.PaystackReference, &subscription.Plan,
        &subscription.Status, &subscription.Amount, &subscription.Currency, &subscription.AuthorizationCode, &subscription.CustomerCode, &subscription.StartDate,
        &subscription.EndDate, &subscription.NextBillingDate, &subscription.CreatedAt, &subscription.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No subscription
		}
		return nil, err
	}

	return &subscription, nil
}

func UpdateSubscriptionStatus(db *sql.DB, paystackRef, status string) error {
	_, err := db.Exec(`
		UPDATE subscriptions SET status = $1, updated_at = $2
		WHERE paystack_reference = $3`,
		status, time.Now(), paystackRef)

	return err
}

func CheckSubscriptionLimits(db *sql.DB, userID uuid.UUID, plan string) (int, int, error) {
	// Get user's current usage
	var boardCount, cardCount int
	
	err := db.QueryRow(`
		SELECT COUNT(*) FROM boards WHERE user_id = $1 AND is_active = true`,
		userID).Scan(&boardCount)
	if err != nil {
		return 0, 0, err
	}

	err = db.QueryRow(`
		SELECT COUNT(*) FROM cards c
		JOIN columns col ON c.column_id = col.id
		JOIN boards b ON col.board_id = b.id
		WHERE b.user_id = $1 AND b.is_active = true`,
		userID).Scan(&cardCount)
	if err != nil {
		return 0, 0, err
	}

	// Get plan limits
	var maxBoards, maxCards int
	switch plan {
	case "basic":
		maxBoards, maxCards = 3, 50
	case "pro", "enterprise":
		maxBoards, maxCards = -1, -1 // Unlimited
	default:
		return 0, 0, fmt.Errorf("invalid plan")
	}

	return maxBoards, maxCards, nil
}

func RecordPayment(db *sql.DB, userID uuid.UUID, subscriptionID *uuid.UUID, reference string, amount int, currency string, status string, channel string, paidAt *time.Time) error {
    // Check if payment with this reference already exists to prevent duplicates
    var existingCount int
    err := db.QueryRow("SELECT COUNT(*) FROM payments WHERE reference = $1", reference).Scan(&existingCount)
    if err != nil {
        return err
    }
    
    if existingCount > 0 {
        // Payment already recorded, skip to prevent duplicate
        return nil
    }
    
    _, err = db.Exec(`
        INSERT INTO payments (id, user_id, subscription_id, reference, amount, currency, status, paid_at, channel, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        uuid.New(), userID, subscriptionID, reference, amount, currency, status, paidAt, channel, time.Now())
    return err
}

func GetPaymentHistory(db *sql.DB, userID uuid.UUID) ([]models.Payment, error) {
    rows, err := db.Query(`
        SELECT id, user_id, subscription_id, reference, amount, currency, status, paid_at, channel, created_at
        FROM payments WHERE user_id = $1 ORDER BY created_at DESC`, userID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var payments []models.Payment
    for rows.Next() {
        var p models.Payment
        var subID sql.NullString
        var paidAt sql.NullTime
        // currency and channel can be NULL in DB, scan into NullString and map safely
        var currency sql.NullString
        var channel sql.NullString
        err := rows.Scan(&p.ID, &p.UserID, &subID, &p.Reference, &p.Amount, &currency, &p.Status, &paidAt, &channel, &p.CreatedAt)
        if err != nil {
            return nil, err
        }
        if currency.Valid {
            p.Currency = currency.String
        } else {
            p.Currency = "NGN"
        }
        if channel.Valid {
            p.Channel = channel.String
        } else {
            p.Channel = ""
        }
        if subID.Valid {
            uid, err := uuid.Parse(subID.String)
            if err == nil {
                p.SubscriptionID = &uid
            }
        }
        if paidAt.Valid {
            t := paidAt.Time
            p.PaidAt = &t
        }
        payments = append(payments, p)
    }
    return payments, nil
}

func RenewDueSubscriptions(db *sql.DB, paystack *PaystackService) error {
    // Find active subscriptions that are due for renewal and have reusable authorization
    rows, err := db.Query(`
        SELECT id, user_id, plan, amount, currency, authorization_code, customer_code
        FROM subscriptions
        WHERE status = 'active' AND next_billing_date IS NOT NULL AND next_billing_date <= NOW() AND authorization_code IS NOT NULL AND authorization_code <> ''`)
    if err != nil {
        return err
    }
    defer rows.Close()

    for rows.Next() {
        var subID uuid.UUID
        var userID uuid.UUID
        var plan string
        var amount int
        var currency string
        var authCode string
        var customerCode string
        if err := rows.Scan(&subID, &userID, &plan, &amount, &currency, &authCode, &customerCode); err != nil {
            return err
        }

        // Get user email
        user, err := GetUserByID(db, userID)
        if err != nil {
            continue
        }

        // Charge authorization
        chargeResp, err := paystack.ChargeAuthorization(user.Email, amount, authCode)
        if err != nil {
            // mark past_due
            _ = UpdateSubscriptionStatus(db, "", "past_due")
            continue
        }

        if chargeResp.Status {
            // Extend subscription by one cycle (monthly)
            startDate := time.Now()
            endDate := startDate.AddDate(0, 1, 0)
            nextBilling := endDate

            // Update subscription dates and last reference
            _, err = db.Exec(`
                UPDATE subscriptions
                SET paystack_reference = $1, start_date = $2, end_date = $3, next_billing_date = $4, updated_at = $5
                WHERE id = $6`,
                chargeResp.Data.Reference, startDate, endDate, nextBilling, time.Now(), subID)
            if err != nil {
                continue
            }

            // Record payment
            paidAt := time.Now()
            _ = RecordPayment(db, userID, &subID, chargeResp.Data.Reference, amount, currency, "success", "card", &paidAt)
        }
    }

    return nil
}

func CanCreateBoard(db *sql.DB, userID uuid.UUID) (bool, error) {
	subscription, err := GetUserSubscription(db, userID)
	if err != nil {
		return false, err
	}

	if subscription == nil {
		// No subscription, check if user has any boards (free tier)
		var boardCount int
		err := db.QueryRow(`
			SELECT COUNT(*) FROM boards WHERE user_id = $1 AND is_active = true`,
			userID).Scan(&boardCount)
		if err != nil {
			return false, err
		}
		return boardCount < 1, nil // Free tier allows 1 board
	}

	maxBoards, _, err := CheckSubscriptionLimits(db, userID, subscription.Plan)
	if err != nil {
		return false, err
	}

	if maxBoards == -1 {
		return true, nil // Unlimited
	}

	var boardCount int
	err = db.QueryRow(`
		SELECT COUNT(*) FROM boards WHERE user_id = $1 AND is_active = true`,
		userID).Scan(&boardCount)
	if err != nil {
		return false, err
	}

	return boardCount < maxBoards, nil
}

func CanCreateCard(db *sql.DB, userID uuid.UUID) (bool, error) {
	subscription, err := GetUserSubscription(db, userID)
	if err != nil {
		return false, err
	}

	if subscription == nil {
		// No subscription, check if user has any cards (free tier)
		var cardCount int
		err := db.QueryRow(`
			SELECT COUNT(*) FROM cards c
			JOIN columns col ON c.column_id = col.id
			JOIN boards b ON col.board_id = b.id
			WHERE b.user_id = $1 AND b.is_active = true`,
			userID).Scan(&cardCount)
		if err != nil {
			return false, err
		}
		return cardCount < 10, nil // Free tier allows 10 cards
	}

	_, maxCards, err := CheckSubscriptionLimits(db, userID, subscription.Plan)
	if err != nil {
		return false, err
	}

	if maxCards == -1 {
		return true, nil // Unlimited
	}

	var cardCount int
	err = db.QueryRow(`
		SELECT COUNT(*) FROM cards c
		JOIN columns col ON c.column_id = col.id
		JOIN boards b ON col.board_id = b.id
		WHERE b.user_id = $1 AND b.is_active = true`,
		userID).Scan(&cardCount)
	if err != nil {
		return false, err
	}

	return cardCount < maxCards, nil
}
