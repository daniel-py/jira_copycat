package database

import (
	"database/sql"
	"fmt"
	"log"

	"jira-copycat-backend/internal/config"

	_ "github.com/lib/pq"
)

func Initialize() (*sql.DB, error) {
    // Prefer a full connection URL if provided (e.g., from Neon or Render)
    if databaseURL := config.GetEnv("DATABASE_URL", ""); databaseURL != "" {
        db, err := sql.Open("postgres", databaseURL)
        if err != nil {
            return nil, err
        }
        if err = db.Ping(); err != nil {
            return nil, err
        }
        log.Println("Successfully connected to database via DATABASE_URL")
        return db, nil
    }

	host := config.GetEnv("DB_HOST", "localhost")
	port := config.GetEnv("DB_PORT", "5432")
	user := config.GetEnv("DB_USER", "postgres")
	password := config.GetEnv("DB_PASSWORD", "password")
	dbname := config.GetEnv("DB_NAME", "jira_copycat")
    sslmode := config.GetEnv("DB_SSLMODE", "disable")

    psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
        host, port, user, password, dbname, sslmode)

	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		return nil, err
	}

	if err = db.Ping(); err != nil {
		return nil, err
	}

	log.Println("Successfully connected to database")
	return db, nil
}

func RunMigrations(db *sql.DB) error {
	migrations := []string{
		createUsersTable,
		createBoardsTable,
		createColumnsTable,
		createCardsTable,
		createSubscriptionsTable,
        alterSubscriptionsAddBillingFields,
        createPaymentsTable,
		createIndexes,
	}

	for _, migration := range migrations {
		if _, err := db.Exec(migration); err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}
	}

	log.Println("Database migrations completed successfully")
	return nil
}

const createUsersTable = `
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

const createBoardsTable = `
CREATE TABLE IF NOT EXISTS boards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(7) DEFAULT '#3B82F6',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

const createColumnsTable = `
CREATE TABLE IF NOT EXISTS columns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id UUID NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    color VARCHAR(7) DEFAULT '#6B7280',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

const createCardsTable = `
CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    column_id UUID NOT NULL REFERENCES columns(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    position INTEGER NOT NULL DEFAULT 0,
    color VARCHAR(7) DEFAULT '#FFFFFF',
    due_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

const createSubscriptionsTable = `
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    paystack_reference VARCHAR(255) UNIQUE NOT NULL,
    plan VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    amount INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'NGN',
    authorization_code VARCHAR(255),
    customer_code VARCHAR(255),
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    next_billing_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);`

const alterSubscriptionsAddBillingFields = `
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS authorization_code VARCHAR(255);
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS customer_code VARCHAR(255);
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS next_billing_date TIMESTAMP;
`

const createPaymentsTable = `
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    reference VARCHAR(255) UNIQUE NOT NULL,
    amount INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'NGN',
    status VARCHAR(50) NOT NULL,
    paid_at TIMESTAMP,
    channel VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
`

const createIndexes = `
CREATE INDEX IF NOT EXISTS idx_boards_user_id ON boards(user_id);
CREATE INDEX IF NOT EXISTS idx_columns_board_id ON columns(board_id);
CREATE INDEX IF NOT EXISTS idx_cards_column_id ON cards(column_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_paystack_ref ON subscriptions(paystack_reference);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_subscription_id ON payments(subscription_id);
`
