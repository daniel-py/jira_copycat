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

    // Start daily renewal worker
    go func() {
        ticker := time.NewTicker(24 * time.Hour)
        defer ticker.Stop()
        paystack := services.NewPaystackService()
        
        // Run immediately on startup
        if err := services.RenewDueSubscriptions(db, paystack); err != nil {
            log.Println("Initial renewal worker error:", err)
        }
        
        for {
            <-ticker.C
            if err := services.RenewDueSubscriptions(db, paystack); err != nil {
                log.Println("Daily renewal worker error:", err)
            }
        }
    }()

    // Start backup renewal worker (runs 6 hours after main worker)
    go func() {
        // Wait 6 hours before starting backup worker
        time.Sleep(6 * time.Hour)
        
        ticker := time.NewTicker(24 * time.Hour)
        defer ticker.Stop()
        paystack := services.NewPaystackService()
        
        for {
            <-ticker.C
            // Check if main worker ran successfully in the last 12 hours
            if !services.HasRecentSuccessfulRenewal(db) {
                log.Println("Backup renewal worker starting - main worker may have failed")
                if err := services.RenewDueSubscriptions(db, paystack); err != nil {
                    log.Println("Backup renewal worker error:", err)
                }
            }
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
