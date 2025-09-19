package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"jira-copycat-backend/internal/models"

	"github.com/google/uuid"
)

func CreateBoard(db *sql.DB, userID uuid.UUID, req models.BoardCreate) (*models.Board, error) {
	board := &models.Board{
		ID:          uuid.New(),
		UserID:      userID,
		Name:        req.Name,
		Description: req.Description,
		Color:       req.Color,
		IsActive:    true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if board.Color == "" {
		board.Color = "#3B82F6"
	}

	_, err := db.Exec(`
		INSERT INTO boards (id, user_id, name, description, color, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		board.ID, board.UserID, board.Name, board.Description, board.Color, board.IsActive, board.CreatedAt, board.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return board, nil
}

func GetUserBoards(db *sql.DB, userID uuid.UUID) ([]models.Board, error) {
	rows, err := db.Query(`
		SELECT id, user_id, name, description, color, is_active, created_at, updated_at
		FROM boards WHERE user_id = $1 AND is_active = true
		ORDER BY created_at DESC`,
		userID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var boards []models.Board
	for rows.Next() {
		var board models.Board
		err := rows.Scan(
			&board.ID, &board.UserID, &board.Name, &board.Description,
			&board.Color, &board.IsActive, &board.CreatedAt, &board.UpdatedAt)
		if err != nil {
			return nil, err
		}
		boards = append(boards, board)
	}

	return boards, nil
}

func GetBoardByID(db *sql.DB, boardID, userID uuid.UUID) (*models.Board, error) {
	var board models.Board
	err := db.QueryRow(`
		SELECT id, user_id, name, description, color, is_active, created_at, updated_at
		FROM boards WHERE id = $1 AND user_id = $2 AND is_active = true`,
		boardID, userID).Scan(
		&board.ID, &board.UserID, &board.Name, &board.Description,
		&board.Color, &board.IsActive, &board.CreatedAt, &board.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &board, nil
}

func UpdateBoard(db *sql.DB, boardID, userID uuid.UUID, req models.BoardUpdate) (*models.Board, error) {
	// Build dynamic update query
	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", argIndex))
		args = append(args, *req.Name)
		argIndex++
	}
	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", argIndex))
		args = append(args, *req.Description)
		argIndex++
	}
	if req.Color != nil {
		setParts = append(setParts, fmt.Sprintf("color = $%d", argIndex))
		args = append(args, *req.Color)
		argIndex++
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argIndex))
		args = append(args, *req.IsActive)
		argIndex++
	}

	if len(setParts) == 0 {
		return GetBoardByID(db, boardID, userID)
	}

	setParts = append(setParts, "updated_at = $"+fmt.Sprintf("%d", argIndex))
	args = append(args, time.Now())
	argIndex++

	args = append(args, boardID, userID)

	query := fmt.Sprintf(`
		UPDATE boards SET %s
		WHERE id = $%d AND user_id = $%d AND is_active = true
		RETURNING id, user_id, name, description, color, is_active, created_at, updated_at`,
		strings.Join(setParts, ", "), argIndex, argIndex+1)

	var board models.Board
	err := db.QueryRow(query, args...).Scan(
		&board.ID, &board.UserID, &board.Name, &board.Description,
		&board.Color, &board.IsActive, &board.CreatedAt, &board.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &board, nil
}

func DeleteBoard(db *sql.DB, boardID, userID uuid.UUID) error {
	_, err := db.Exec(`
		UPDATE boards SET is_active = false, updated_at = $1
		WHERE id = $2 AND user_id = $3`,
		time.Now(), boardID, userID)

	return err
}
