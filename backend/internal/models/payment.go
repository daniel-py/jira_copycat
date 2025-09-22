package models

import (
	"time"

	"github.com/google/uuid"
)

type Payment struct {
    ID             uuid.UUID `json:"id" db:"id"`
    UserID         uuid.UUID `json:"user_id" db:"user_id"`
    SubscriptionID *uuid.UUID `json:"subscription_id,omitempty" db:"subscription_id"`
    Reference      string    `json:"reference" db:"reference"`
    Amount         int       `json:"amount" db:"amount"`
    Currency       string    `json:"currency" db:"currency"`
    Status         string    `json:"status" db:"status"`
    PaidAt         *time.Time `json:"paid_at,omitempty" db:"paid_at"`
    Channel        string    `json:"channel" db:"channel"`
    CreatedAt      time.Time `json:"created_at" db:"created_at"`
}



