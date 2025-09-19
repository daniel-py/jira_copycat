package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"jira-copycat-backend/internal/models"

	"github.com/google/uuid"
)

func CreateColumn(db *sql.DB, boardID, userID uuid.UUID, req models.ColumnCreate) (*models.Column, error) {
	// Verify board belongs to user
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM boards WHERE id = $1 AND user_id = $2 AND is_active = true)`,
		boardID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("board not found or access denied")
	}

	// Get next position if not provided
	if req.Position == 0 {
		var maxPos int
		db.QueryRow(`
			SELECT COALESCE(MAX(position), 0) FROM columns WHERE board_id = $1`,
			boardID).Scan(&maxPos)
		req.Position = maxPos + 1
	}

	column := &models.Column{
		ID:        uuid.New(),
		BoardID:   boardID,
		Name:      req.Name,
		Position:  req.Position,
		Color:     req.Color,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if column.Color == "" {
		column.Color = "#6B7280"
	}

	_, err = db.Exec(`
		INSERT INTO columns (id, board_id, name, position, color, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		column.ID, column.BoardID, column.Name, column.Position, column.Color, column.CreatedAt, column.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return column, nil
}

func GetBoardColumns(db *sql.DB, boardID, userID uuid.UUID) ([]models.Column, error) {
	// Verify board belongs to user
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM boards WHERE id = $1 AND user_id = $2 AND is_active = true)`,
		boardID, userID).Scan(&exists)
	if err != nil || !exists {
		return nil, fmt.Errorf("board not found or access denied")
	}

	rows, err := db.Query(`
		SELECT id, board_id, name, position, color, created_at, updated_at
		FROM columns WHERE board_id = $1
		ORDER BY position ASC`,
		boardID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var columns []models.Column
	for rows.Next() {
		var column models.Column
		err := rows.Scan(
			&column.ID, &column.BoardID, &column.Name, &column.Position,
			&column.Color, &column.CreatedAt, &column.UpdatedAt)
		if err != nil {
			return nil, err
		}
		columns = append(columns, column)
	}

	return columns, nil
}

func UpdateColumn(db *sql.DB, columnID, userID uuid.UUID, req models.ColumnUpdate) (*models.Column, error) {
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

	// Build dynamic update query
	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", argIndex))
		args = append(args, *req.Name)
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

	if len(setParts) == 0 {
		// Return existing column if no updates
		return getColumnByID(db, columnID)
	}

	setParts = append(setParts, "updated_at = $"+fmt.Sprintf("%d", argIndex))
	args = append(args, time.Now())
	argIndex++

	args = append(args, columnID)

	query := fmt.Sprintf(`
		UPDATE columns SET %s
		WHERE id = $%d
		RETURNING id, board_id, name, position, color, created_at, updated_at`,
		strings.Join(setParts, ", "), argIndex)

	var column models.Column
	err = db.QueryRow(query, args...).Scan(
		&column.ID, &column.BoardID, &column.Name, &column.Position,
		&column.Color, &column.CreatedAt, &column.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &column, nil
}

func DeleteColumn(db *sql.DB, columnID, userID uuid.UUID) error {
	// Verify column belongs to user's board
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM columns c
			JOIN boards b ON c.board_id = b.id
			WHERE c.id = $1 AND b.user_id = $2 AND b.is_active = true
		)`, columnID, userID).Scan(&exists)
	if err != nil || !exists {
		return fmt.Errorf("column not found or access denied")
	}

	_, err = db.Exec("DELETE FROM columns WHERE id = $1", columnID)
	return err
}

func getColumnByID(db *sql.DB, columnID uuid.UUID) (*models.Column, error) {
	var column models.Column
	err := db.QueryRow(`
		SELECT id, board_id, name, position, color, created_at, updated_at
		FROM columns WHERE id = $1`,
		columnID).Scan(
		&column.ID, &column.BoardID, &column.Name, &column.Position,
		&column.Color, &column.CreatedAt, &column.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &column, nil
}