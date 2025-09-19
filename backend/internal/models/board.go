package models

import (
	"time"

	"github.com/google/uuid"
)

type Board struct {
	ID          uuid.UUID `json:"id" db:"id"`
	UserID      uuid.UUID `json:"user_id" db:"user_id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	Color       string    `json:"color" db:"color"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type BoardCreate struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
	Color       string `json:"color"`
}

type BoardUpdate struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	Color       *string `json:"color,omitempty"`
	IsActive    *bool   `json:"is_active,omitempty"`
}

type Column struct {
	ID        uuid.UUID `json:"id" db:"id"`
	BoardID   uuid.UUID `json:"board_id" db:"board_id"`
	Name      string    `json:"name" db:"name"`
	Position  int       `json:"position" db:"position"`
	Color     string    `json:"color" db:"color"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

type ColumnCreate struct {
	Name     string `json:"name" binding:"required"`
	Position int    `json:"position"`
	Color    string `json:"color"`
}

type ColumnUpdate struct {
	Name     *string `json:"name,omitempty"`
	Position *int    `json:"position,omitempty"`
	Color    *string `json:"color,omitempty"`
}

type Card struct {
	ID          uuid.UUID `json:"id" db:"id"`
	ColumnID    uuid.UUID `json:"column_id" db:"column_id"`
	Title       string    `json:"title" db:"title"`
	Description string    `json:"description" db:"description"`
	Position    int       `json:"position" db:"position"`
	Color       string    `json:"color" db:"color"`
	DueDate     *time.Time `json:"due_date,omitempty" db:"due_date"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type CardCreate struct {
	Title       string     `json:"title" binding:"required"`
	Description string     `json:"description"`
	Position    int        `json:"position"`
	Color       string     `json:"color"`
	DueDate     *time.Time `json:"due_date,omitempty"`
}

type CardUpdate struct {
	Title       *string    `json:"title,omitempty"`
	Description *string    `json:"description,omitempty"`
	Position    *int       `json:"position,omitempty"`
	Color       *string    `json:"color,omitempty"`
	DueDate     *time.Time `json:"due_date,omitempty"`
}

type CardMove struct {
	ColumnID uuid.UUID `json:"column_id" binding:"required"`
	Position int       `json:"position" binding:"required"`
}
