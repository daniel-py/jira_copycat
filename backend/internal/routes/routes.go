package routes

import (
	"database/sql"

	"jira-copycat-backend/internal/handlers"
	"jira-copycat-backend/internal/middleware"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func SetupRoutes(db *sql.DB) *gin.Engine {
	router := gin.Default()

	// CORS configuration
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"*"} // Configure this properly for production
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization"}
	router.Use(cors.New(config))

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(db)
	boardHandler := handlers.NewBoardHandler(db)
	columnHandler := handlers.NewColumnHandler(db)
	cardHandler := handlers.NewCardHandler(db)
	billingHandler := handlers.NewBillingHandler(db)

	// Public routes
	api := router.Group("/api")
	{
		// Authentication routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
		}

		// Billing routes (some public, some protected)
		billing := api.Group("/billing")
		{
			billing.GET("/plans", billingHandler.GetPlans)
			billing.POST("/webhook", billingHandler.Webhook) // Paystack webhook
		}
	}

	// Protected routes
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware())
	{
		// User profile
		protected.GET("/auth/profile", authHandler.GetProfile)

		// Board routes
		boards := protected.Group("/boards")
		{
			boards.GET("", boardHandler.GetBoards)
			boards.POST("", boardHandler.CreateBoard)
			boards.GET("/:id", boardHandler.GetBoard)
			boards.PUT("/:id", boardHandler.UpdateBoard)
			boards.DELETE("/:id", boardHandler.DeleteBoard)

			// Column routes
			boards.GET("/:id/columns", columnHandler.GetColumns)
			boards.POST("/:id/columns", columnHandler.CreateColumn)
			boards.PUT("/columns/:id", columnHandler.UpdateColumn)
			boards.DELETE("/columns/:id", columnHandler.DeleteColumn)

			// Card routes
			boards.GET("/columns/:column_id/cards", cardHandler.GetCards)
			boards.POST("/columns/:column_id/cards", cardHandler.CreateCard)
			boards.PUT("/cards/:id", cardHandler.UpdateCard)
			boards.PUT("/cards/:id/move", cardHandler.MoveCard)
			boards.DELETE("/cards/:id", cardHandler.DeleteCard)
		}

		// Billing routes (protected)
		billing := protected.Group("/billing")
		{
			billing.POST("/subscribe", billingHandler.InitializeSubscription)
			billing.GET("/verify", billingHandler.VerifySubscription)
			billing.GET("/status", billingHandler.GetSubscriptionStatus)
			billing.GET("/payments", billingHandler.GetPaymentHistory)
			billing.GET("/2fa-status", billingHandler.Get2FAStatus)
			billing.GET("/2fa-url", billingHandler.Get2FAURL)
		}
	}

	return router
}
