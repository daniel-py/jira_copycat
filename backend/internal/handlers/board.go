package handlers

import (
	"database/sql"
	"fmt"
	"net/http"

	"jira-copycat-backend/internal/models"
	"jira-copycat-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type BoardHandler struct {
	db *sql.DB
}

func NewBoardHandler(db *sql.DB) *BoardHandler {
	return &BoardHandler{db: db}
}

func (h *BoardHandler) CreateBoard(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Check subscription limits
	canCreate, err := services.CanCreateBoard(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check subscription limits"})
		return
	}

	if !canCreate {
		c.JSON(http.StatusForbidden, gin.H{"error": "Subscription limit reached. Please upgrade your plan."})
		return
	}

	var req models.BoardCreate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	board, err := services.CreateBoard(h.db, userID.(uuid.UUID), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"board": board})
}

func (h *BoardHandler) GetBoards(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Check if user can access boards
	canAccess, err := services.CanAccessBoards(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check access permissions"})
		return
	}

	if !canAccess {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Your subscription has expired. Please renew to access your boards.",
			"subscription_expired": true,
		})
		return
	}

	boards, err := services.GetUserBoards(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"boards": boards})
}

// Debug endpoint to test subscription access
func (h *BoardHandler) DebugSubscription(c *gin.Context) {
	defer func() {
		if r := recover(); r != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Panic occurred: " + fmt.Sprintf("%v", r),
				"type": "panic",
			})
		}
	}()

	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Test subscription check
	canAccess, err := services.CanAccessBoards(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "CanAccessBoards failed: " + err.Error(),
			"user_id": userID,
			"type": "canAccessBoards_error",
		})
		return
	}

	// Test board retrieval
	boards, err := services.GetUserBoards(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "GetUserBoards failed: " + err.Error(),
			"can_access": canAccess,
			"user_id": userID,
			"type": "getUserBoards_error",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"can_access": canAccess,
		"boards_count": len(boards),
		"user_id": userID,
		"status": "success",
	})
}

func (h *BoardHandler) GetBoard(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Check if user can access boards
	canAccess, err := services.CanAccessBoards(h.db, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check access permissions"})
		return
	}

	if !canAccess {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Your subscription has expired. Please renew to access your boards.",
			"subscription_expired": true,
		})
		return
	}

	boardID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid board ID"})
		return
	}

	board, err := services.GetBoardByID(h.db, boardID, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Board not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"board": board})
}

func (h *BoardHandler) UpdateBoard(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	boardID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid board ID"})
		return
	}

	var req models.BoardUpdate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	board, err := services.UpdateBoard(h.db, boardID, userID.(uuid.UUID), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"board": board})
}

func (h *BoardHandler) DeleteBoard(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	boardID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid board ID"})
		return
	}

	err = services.DeleteBoard(h.db, boardID, userID.(uuid.UUID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Board deleted successfully"})
}
