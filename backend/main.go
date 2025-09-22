package main

import (
	"log"
	"os"
	"time"

	"jira-copycat-backend/internal/config"
	"jira-copycat-backend/internal/database"
	"jira-copycat-backend/internal/routes"
	"jira-copycat-backend/internal/services"
)

func main() {
	// Load environment variables
	config.LoadEnv()

	// Initialize database
	db, err := database.Initialize()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Run migrations
	if err := database.RunMigrations(db); err != nil {
		log.Fatal("Failed to run migrations:", err)
	}

	// Setup routes
	router := routes.SetupRoutes(db)

    // Start background renewal worker
    go func() {
        ticker := time.NewTicker(1 * time.Hour)
        defer ticker.Stop()
        paystack := services.NewPaystackService()
        for {
            if err := services.RenewDueSubscriptions(db, paystack); err != nil {
                log.Println("Renewal worker error:", err)
            }
            <-ticker.C
        }
    }()

    // Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	log.Fatal(router.Run(":" + port))
}
