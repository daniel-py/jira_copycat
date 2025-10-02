package services

import (
	"database/sql"
	"fmt"
	"log"
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
	var pending2FAReference, pending2FAURL sql.NullString
	
	// First, try to get an active or pending_2fa subscription
	err := db.QueryRow(`
        SELECT id, user_id, paystack_reference, plan, status, amount, currency, authorization_code, customer_code, start_date, end_date, next_billing_date, pending_2fa_reference, pending_2fa_url, pending_2fa_created_at, created_at, updated_at
		FROM subscriptions WHERE user_id = $1 AND status IN ('active', 'pending_2fa')
		ORDER BY created_at DESC LIMIT 1`,
		userID).Scan(
        &subscription.ID, &subscription.UserID, &subscription.PaystackReference, &subscription.Plan,
        &subscription.Status, &subscription.Amount, &subscription.Currency, &subscription.AuthorizationCode, &subscription.CustomerCode, &subscription.StartDate,
        &subscription.EndDate, &subscription.NextBillingDate, &pending2FAReference, &pending2FAURL, &subscription.Pending2FACreatedAt, &subscription.CreatedAt, &subscription.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			// If no active/pending subscription, check for cancelled subscription
			err = db.QueryRow(`
                SELECT id, user_id, paystack_reference, plan, status, amount, currency, authorization_code, customer_code, start_date, end_date, next_billing_date, pending_2fa_reference, pending_2fa_url, pending_2fa_created_at, created_at, updated_at
                FROM subscriptions WHERE user_id = $1 AND status = 'cancelled'
                ORDER BY created_at DESC LIMIT 1`,
                userID).Scan(
                &subscription.ID, &subscription.UserID, &subscription.PaystackReference, &subscription.Plan,
                &subscription.Status, &subscription.Amount, &subscription.Currency, &subscription.AuthorizationCode, &subscription.CustomerCode, &subscription.StartDate,
                &subscription.EndDate, &subscription.NextBillingDate, &pending2FAReference, &pending2FAURL, &subscription.Pending2FACreatedAt, &subscription.CreatedAt, &subscription.UpdatedAt)
            
            if err != nil {
                if err == sql.ErrNoRows {
                    return nil, nil // No subscription found
                }
                return nil, err
            }
		} else {
			return nil, err
		}
	}

	// Handle NULL values for 2FA fields
	if pending2FAReference.Valid {
		subscription.Pending2FAReference = &pending2FAReference.String
	}
	if pending2FAURL.Valid {
		subscription.Pending2FAURL = &pending2FAURL.String
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
	case "basic", "pro", "enterprise":
		maxBoards, maxCards = 5, 50 // All paid plans get 5 boards
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
        INSERT INTO payments (user_id, subscription_id, reference, amount, currency, status, paid_at, channel)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        userID, subscriptionID, reference, amount, currency, status, paidAt, channel)
    return err
}

func GetPaymentHistory(db *sql.DB, userID uuid.UUID) ([]models.Payment, error) {
    fmt.Printf("DEBUG: GetPaymentHistory called for userID: %s\n", userID)
    
    // First, let's check what columns actually exist in the payments table
    rows, err := db.Query(`
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'payments' 
        ORDER BY ordinal_position`)
    if err != nil {
        fmt.Printf("DEBUG: Failed to query information_schema: %v\n", err)
        return nil, err
    }
    defer rows.Close()
    
    var columns []string
    for rows.Next() {
        var colName, dataType string
        if err := rows.Scan(&colName, &dataType); err != nil {
            fmt.Printf("DEBUG: Failed to scan column info: %v\n", err)
            return nil, err
        }
        columns = append(columns, colName)
        fmt.Printf("DEBUG: Column: %s (%s)\n", colName, dataType)
    }
    
    fmt.Printf("DEBUG: Payments table has %d columns: %v\n", len(columns), columns)
    
    // Now try the actual query
    rows, err = db.Query(`
        SELECT id, user_id, subscription_id, reference, amount, currency, status, paid_at, channel, created_at
        FROM payments WHERE user_id = $1 ORDER BY created_at DESC`, userID)
    if err != nil {
        fmt.Printf("DEBUG: Query failed with error: %v\n", err)
        return nil, err
    }
    defer rows.Close()

    fmt.Printf("DEBUG: Query executed successfully, scanning rows...\n")
    
    var payments []models.Payment
    for rows.Next() {
        var p models.Payment
        var subID sql.NullString
        var paidAt sql.NullTime
        // currency and channel can be NULL in DB, scan into NullString and map safely
        var currency sql.NullString
        var channel sql.NullString
        
        fmt.Printf("DEBUG: About to scan row...\n")
        err := rows.Scan(&p.ID, &p.UserID, &subID, &p.Reference, &p.Amount, &currency, &p.Status, &paidAt, &channel, &p.CreatedAt)
        if err != nil {
            fmt.Printf("DEBUG: Scan failed with error: %v\n", err)
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
        fmt.Printf("DEBUG: Successfully scanned payment: %s\n", p.Reference)
    }
    
    fmt.Printf("DEBUG: GetPaymentHistory completed successfully, found %d payments\n", len(payments))
	return payments, nil
}

func LogRenewalAttempt(db *sql.DB, subscriptionID uuid.UUID, status string, errorMessage string) error {
	_, err := db.Exec(`
		INSERT INTO renewal_logs (id, subscription_id, renewal_date, status, error_message, worker_run, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		uuid.New(), subscriptionID, time.Now(), status, errorMessage, false, time.Now())
	return err
}

func LogWorkerRun(db *sql.DB, status, message string) error {
	_, err := db.Exec(`
		INSERT INTO renewal_logs (id, subscription_id, renewal_date, status, error_message, worker_run, created_at)
		VALUES ($1, NULL, $2, $3, $4, $5, $6)`,
		uuid.New(), time.Now(), status, message, true, time.Now())
	return err
}

func HasRecentSuccessfulRenewal(db *sql.DB) bool {
	var count int
	err := db.QueryRow(`
		SELECT COUNT(*) FROM renewal_logs 
		WHERE status = 'success' AND worker_run = true AND created_at > NOW() - INTERVAL '12 hours'`).Scan(&count)
	if err != nil {
		return false
	}
	return count > 0
}

func CancelFailedSubscriptions(db *sql.DB) error {
	// Find subscriptions that haven't been successfully renewed in 3 days
	rows, err := db.Query(`
		SELECT s.id, s.user_id, s.plan
		FROM subscriptions s
		WHERE s.status = 'active' 
		AND s.next_billing_date < NOW() - INTERVAL '3 days'
		AND NOT EXISTS (
			SELECT 1 FROM renewal_logs rl 
			WHERE rl.subscription_id = s.id 
			AND rl.status = 'success' 
			AND rl.created_at > s.next_billing_date
		)`)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var subID, userID uuid.UUID
		var plan string
		if err := rows.Scan(&subID, &userID, &plan); err != nil {
			continue
		}

		// Cancel the subscription
		_, err = db.Exec(`
			UPDATE subscriptions 
			SET status = 'cancelled', updated_at = $1 
			WHERE id = $2`,
			time.Now(), subID)
		if err != nil {
			continue
		}

		// Log the cancellation
		_ = LogRenewalAttempt(db, subID, "cancelled", "Subscription cancelled due to failed renewals for 3+ days")
	}

	return nil
}

func CancelPending2FASubscriptions(db *sql.DB) error {
	// Find subscriptions that have been pending 2FA for 48+ hours
	rows, err := db.Query(`
		SELECT s.id, s.user_id, s.plan
		FROM subscriptions s
		WHERE s.status = 'pending_2fa' 
		AND s.pending_2fa_created_at < NOW() - INTERVAL '48 hours'`)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var subID, userID uuid.UUID
		var plan string
		if err := rows.Scan(&subID, &userID, &plan); err != nil {
			continue
		}

		// Cancel the subscription
		_, err = db.Exec(`
			UPDATE subscriptions 
			SET status = 'cancelled', pending_2fa_reference = NULL, pending_2fa_url = NULL, pending_2fa_created_at = NULL, updated_at = $1 
			WHERE id = $2`,
			time.Now(), subID)
		if err != nil {
			continue
		}

		// Log the cancellation
		_ = LogRenewalAttempt(db, subID, "cancelled", "Subscription cancelled due to 2FA timeout after 48 hours")
	}

	return nil
}

func RenewDueSubscriptions(db *sql.DB, paystack *PaystackService) error {
    // First, cancel subscriptions that have failed for 3+ days
    if err := CancelFailedSubscriptions(db); err != nil {
        log.Printf("Error cancelling failed subscriptions: %v", err)
    }
    
    // Also cancel subscriptions that have been pending 2FA for 48+ hours
    if err := CancelPending2FASubscriptions(db); err != nil {
        log.Printf("Error cancelling pending 2FA subscriptions: %v", err)
    }

    // Find active subscriptions that are due for renewal and have reusable authorization
    rows, err := db.Query(`
        SELECT id, user_id, plan, amount, currency, authorization_code, customer_code
        FROM subscriptions
        WHERE status = 'active' AND next_billing_date IS NOT NULL AND next_billing_date <= NOW() AND authorization_code IS NOT NULL AND authorization_code <> ''`)
    if err != nil {
        // Log the worker run as failed
        _ = LogWorkerRun(db, "failed", "Database query error: "+err.Error())
        return err
    }
    defer rows.Close()

    var renewalCount int
    var successCount int

    for rows.Next() {
        var subID uuid.UUID
        var userID uuid.UUID
        var plan string
        var amount int
        var currency string
        var authCode string
        var customerCode string
        if err := rows.Scan(&subID, &userID, &plan, &amount, &currency, &authCode, &customerCode); err != nil {
            continue
        }

        renewalCount++

        // Get user email
        user, err := GetUserByID(db, userID)
        if err != nil {
            _ = LogRenewalAttempt(db, subID, "failed", "User not found: "+err.Error())
            continue
        }

        // Charge authorization
        chargeResp, err := paystack.ChargeAuthorization(user.Email, amount, authCode)
        if err != nil {
            _ = LogRenewalAttempt(db, subID, "failed", "Paystack error: "+err.Error())
            continue
        }

        if chargeResp.Status {
            if chargeResp.Data.Paused {
                // 2FA required - set subscription to pending_2fa status
                _, err = db.Exec(`
                    UPDATE subscriptions
                    SET status = 'pending_2fa', pending_2fa_reference = $1, pending_2fa_url = $2, pending_2fa_created_at = $3, updated_at = $4
                    WHERE id = $5`,
                    chargeResp.Data.Reference, chargeResp.Data.AuthorizationURL, time.Now(), time.Now(), subID)
                if err != nil {
                    _ = LogRenewalAttempt(db, subID, "failed", "Database update error for 2FA: "+err.Error())
                    continue
                }

                // Log 2FA required
                _ = LogRenewalAttempt(db, subID, "pending_2fa", "2FA required for renewal: "+chargeResp.Data.AuthorizationURL)
                
                // TODO: Send email notification to user about 2FA requirement
                log.Printf("2FA required for subscription %s, user: %s", subID, user.Email)
            } else {
                // Successful charge - extend subscription by one cycle (monthly)
                startDate := time.Now()
                endDate := startDate.AddDate(0, 1, 0)
                nextBilling := endDate

                // Update subscription dates and clear any pending 2FA
                _, err = db.Exec(`
                    UPDATE subscriptions
                    SET paystack_reference = $1, start_date = $2, end_date = $3, next_billing_date = $4, 
                        status = 'active', pending_2fa_reference = NULL, pending_2fa_url = NULL, pending_2fa_created_at = NULL, updated_at = $5
                    WHERE id = $6`,
                    chargeResp.Data.Reference, startDate, endDate, nextBilling, time.Now(), subID)
                if err != nil {
                    _ = LogRenewalAttempt(db, subID, "failed", "Database update error: "+err.Error())
                    continue
                }

                // Record payment
                paidAt := time.Now()
                _ = RecordPayment(db, userID, &subID, chargeResp.Data.Reference, amount, currency, "success", "card", &paidAt)
                
                // Log successful renewal
                _ = LogRenewalAttempt(db, subID, "success", "")
                successCount++
            }
        } else {
            _ = LogRenewalAttempt(db, subID, "failed", "Paystack returned failure: "+chargeResp.Message)
        }
    }

    // Always log the worker run as successful if it executed without errors
    // The worker succeeded even if individual renewals failed (due to card issues, etc.)
    message := fmt.Sprintf("Processed %d renewals, %d successful", renewalCount, successCount)
    _ = LogWorkerRun(db, "success", message)
    log.Printf("Renewal process completed: %d processed, %d successful", renewalCount, successCount)
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

// CanAccessBoards checks if user can access their boards based on subscription status
func CanAccessBoards(db *sql.DB, userID uuid.UUID) (bool, error) {
	subscription, err := GetUserSubscription(db, userID)
	if err != nil {
		return false, err
	}

	if subscription == nil {
		// No subscription - free tier, can access 1 board
		return true, nil
	}

	// Check if subscription is active
	if subscription.Status != "active" {
		return false, nil // Subscription expired or cancelled - no access
	}

	// Check if subscription has expired
	if time.Now().After(subscription.EndDate) {
		return false, nil // Subscription expired - no access
	}

	return true, nil // Active subscription - full access
}

