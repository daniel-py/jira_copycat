package services

import (
	"database/sql"
	"fmt"
	"time"

	"jira-copycat-backend/internal/models"

	"github.com/google/uuid"
)

func CreateSubscription(db *sql.DB, userID uuid.UUID, paystackRef, plan string, amount int) (*models.Subscription, error) {
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

	subscription := &models.Subscription{
		ID:                uuid.New(),
		UserID:            userID,
		PaystackReference: paystackRef,
		Plan:              plan,
		Status:            "active",
		Amount:            amount,
		Currency:          "NGN",
		StartDate:         startDate,
		EndDate:           endDate,
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}

	_, err := db.Exec(`
		INSERT INTO subscriptions (id, user_id, paystack_reference, plan, status, amount, currency, start_date, end_date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
		subscription.ID, subscription.UserID, subscription.PaystackReference, subscription.Plan,
		subscription.Status, subscription.Amount, subscription.Currency, subscription.StartDate,
		subscription.EndDate, subscription.CreatedAt, subscription.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return subscription, nil
}

func GetUserSubscription(db *sql.DB, userID uuid.UUID) (*models.Subscription, error) {
	var subscription models.Subscription
	err := db.QueryRow(`
		SELECT id, user_id, paystack_reference, plan, status, amount, currency, start_date, end_date, created_at, updated_at
		FROM subscriptions WHERE user_id = $1 AND status = 'active'
		ORDER BY created_at DESC LIMIT 1`,
		userID).Scan(
		&subscription.ID, &subscription.UserID, &subscription.PaystackReference, &subscription.Plan,
		&subscription.Status, &subscription.Amount, &subscription.Currency, &subscription.StartDate,
		&subscription.EndDate, &subscription.CreatedAt, &subscription.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // No active subscription
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
