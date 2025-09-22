package models

import (
	"time"

	"github.com/google/uuid"
)

type Subscription struct {
	ID                uuid.UUID `json:"id" db:"id"`
	UserID            uuid.UUID `json:"user_id" db:"user_id"`
	PaystackReference string    `json:"paystack_reference" db:"paystack_reference"`
	Plan              string    `json:"plan" db:"plan"` // "basic", "pro", "enterprise"
	Status            string    `json:"status" db:"status"` // "active", "cancelled", "expired"
	Amount            int       `json:"amount" db:"amount"` // Amount in kobo (Nigerian currency)
	Currency          string    `json:"currency" db:"currency"`
    AuthorizationCode string    `json:"authorization_code" db:"authorization_code"`
    CustomerCode      string    `json:"customer_code" db:"customer_code"`
	StartDate         time.Time `json:"start_date" db:"start_date"`
	EndDate           time.Time `json:"end_date" db:"end_date"`
    NextBillingDate   time.Time `json:"next_billing_date" db:"next_billing_date"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

type SubscriptionCreate struct {
	Plan   string `json:"plan" binding:"required,oneof=basic pro enterprise"`
	Amount int    `json:"amount" binding:"required,min=1"`
}

type PaystackResponse struct {
	Status  bool   `json:"status"`
	Message string `json:"message"`
	Data    struct {
		Reference string `json:"reference"`
		AccessCode string `json:"access_code"`
		AuthorizationURL string `json:"authorization_url"`
	} `json:"data"`
}

type PaystackVerifyResponse struct {
	Status  bool   `json:"status"`
	Message string `json:"message"`
	Data    struct {
		Reference string `json:"reference"`
		Status    string `json:"status"`
		Amount    int    `json:"amount"`
		Currency  string `json:"currency"`
        Channel   string `json:"channel"`
		Metadata  struct {
			Plan string `json:"plan"`
		} `json:"metadata"`
		Customer  struct {
			Email string `json:"email"`
            CustomerCode string `json:"customer_code"`
		} `json:"customer"`
        Authorization struct {
            AuthorizationCode string `json:"authorization_code"`
            CardType          string `json:"card_type"`
            Bank              string `json:"bank"`
            CountryCode       string `json:"country_code"`
            Brand             string `json:"brand"`
            Last4             string `json:"last4"`
            Reusable          bool   `json:"reusable"`
        } `json:"authorization"`
	} `json:"data"`
}

type SubscriptionPlan struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Price       int    `json:"price"` // Price in kobo
	Currency    string `json:"currency"`
	Features    []string `json:"features"`
	MaxBoards   int    `json:"max_boards"`
	MaxCards    int    `json:"max_cards"`
}
