package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"jira-copycat-backend/internal/models"

	"github.com/google/uuid"
)

func CreateCard(db *sql.DB, columnID, userID uuid.UUID, req models.CardCreate) (*models.Card, error) {
	// Verify column belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM columns c
			JOIN boards b ON c.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, columnID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("column not found or access denied")
	}

	// Get next position if not provided
	if req.Position == 0 {
		var maxPos int
		db.QueryRow(`
			SELECT COALESCE(MAX(position), 0) FROM cards WHERE column_id = $1`,
			columnID).Scan(&maxPos)
		req.Position = maxPos + 1
	}

	card := &models.Card{
		ID:          uuid.New(),
		ColumnID:    columnID,
		Title:       req.Title,
		Description: req.Description,
		Position:    req.Position,
		Color:       req.Color,
		DueDate:     req.DueDate,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if card.Color == "" {
		card.Color = "#FFFFFF"
	}

	_, err = db.Exec(`
		INSERT INTO cards (id, column_id, title, description, position, color, due_date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		card.ID, card.ColumnID, card.Title, card.Description, card.Position, card.Color, card.DueDate, card.CreatedAt, card.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return card, nil
}

func GetColumnCards(db *sql.DB, columnID, userID uuid.UUID) ([]models.Card, error) {
	// Verify column belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM columns c
			JOIN boards b ON c.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, columnID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("column not found or access denied")
	}

	rows, err := db.Query(`
		SELECT id, column_id, title, description, position, color, due_date, created_at, updated_at
		FROM cards WHERE column_id = $1
		ORDER BY position ASC`,
		columnID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cards []models.Card
	for rows.Next() {
		var card models.Card
		err := rows.Scan(
			&card.ID, &card.ColumnID, &card.Title, &card.Description, &card.Position,
			&card.Color, &card.DueDate, &card.CreatedAt, &card.UpdatedAt)
		if err != nil {
			return nil, err
		}
		cards = append(cards, card)
	}

	return cards, nil
}

func UpdateCard(db *sql.DB, cardID, userID uuid.UUID, req models.CardUpdate) (*models.Card, error) {
	// Verify card belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM cards c
			JOIN columns col ON c.column_id = col.id
			JOIN boards b ON col.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, cardID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("card not found or access denied")
	}

	// Build dynamic update query
	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.Title != nil {
		setParts = append(setParts, fmt.Sprintf("title = $%d", argIndex))
		args = append(args, *req.Title)
		argIndex++
	}
	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", argIndex))
		args = append(args, *req.Description)
		argIndex++
	}
	if req.Position != nil {
		setParts = append(setParts, fmt.Sprintf("position = $%d", argIndex))
		args = append(args, *req.Position)
		argIndex++
	}
	if req.Color != nil {
		setParts = append(setParts, fmt.Sprintf("color = $%d", argIndex))
		args = append(args, *req.Color)
		argIndex++
	}
	if req.DueDate != nil {
		setParts = append(setParts, fmt.Sprintf("due_date = $%d", argIndex))
		args = append(args, *req.DueDate)
		argIndex++
	}

	if len(setParts) == 0 {
		// Return existing card if no updates
		return getCardByID(db, cardID)
	}

	setParts = append(setParts, "updated_at = $"+fmt.Sprintf("%d", argIndex))
	args = append(args, time.Now())
	argIndex++

	args = append(args, cardID)

	query := fmt.Sprintf(`
		UPDATE cards SET %s
		WHERE id = $%d
		RETURNING id, column_id, title, description, position, color, due_date, created_at, updated_at`,
		strings.Join(setParts, ", "), argIndex)

	var card models.Card
	err = db.QueryRow(query, args...).Scan(
		&card.ID, &card.ColumnID, &card.Title, &card.Description, &card.Position,
		&card.Color, &card.DueDate, &card.CreatedAt, &card.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &card, nil
}

func MoveCard(db *sql.DB, cardID, userID uuid.UUID, req models.CardMove) (*models.Card, error) {
	// Verify card belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM cards c
			JOIN columns col ON c.column_id = col.id
			JOIN boards b ON col.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, cardID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("card not found or access denied")
	}

	// Verify target column belongs to user's board
	err = db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM columns c
			JOIN boards b ON c.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, req.ColumnID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("target column not found or access denied")
	}

	// Update card position and column
	_, err = db.Exec(`
		UPDATE cards SET column_id = $1, position = $2, updated_at = $3
		WHERE id = $4`,
		req.ColumnID, req.Position, time.Now(), cardID)

	if err != nil {
		return nil, err
	}

	return getCardByID(db, cardID)
}

func DeleteCard(db *sql.DB, cardID, userID uuid.UUID) error {
	// Verify card belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM cards c
			JOIN columns col ON c.column_id = col.id
			JOIN boards b ON col.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, cardID, userID).Scan(&exists)
	if err != nil || !exists {
		return fmt.Errorf("card not found or access denied")
	}

	_, err = db.Exec("DELETE FROM cards WHERE id = $1", cardID)
	return err
}

func getCardByID(db *sql.DB, cardID uuid.UUID) (*models.Card, error) {
	var card models.Card
	err := db.QueryRow(`
		SELECT id, column_id, title, description, position, color, due_date, created_at, updated_at
		FROM cards WHERE id = $1`,
		cardID).Scan(
		&card.ID, &card.ColumnID, &card.Title, &card.Description, &card.Position,
		&card.Color, &card.DueDate, &card.CreatedAt, &card.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &card, nil
}
