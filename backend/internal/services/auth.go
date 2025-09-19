package services

import (
	"database/sql"
	"errors"
	"time"

	"jira-copycat-backend/internal/config"
	"jira-copycat-backend/internal/models"

	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var jwtSecret = []byte(config.GetEnv("JWT_SECRET", "your-secret-key"))

type Claims struct {
	UserID uuid.UUID `json:"user_id"`
	Email  string    `json:"email"`
	jwt.RegisteredClaims
}

func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func GenerateToken(userID uuid.UUID, email string) (string, error) {
	expirationTime := time.Now().Add(24 * time.Hour)
	claims := &Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

func ValidateToken(tokenString string) (uuid.UUID, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})

	if err != nil {
		return uuid.Nil, err
	}

	if !token.Valid {
		return uuid.Nil, errors.New("invalid token")
	}

	return claims.UserID, nil
}

func RegisterUser(db *sql.DB, req models.UserRegistration) (*models.User, error) {
	// Normalize email
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	// Check if user already exists
	var existingUser models.User
	err := db.QueryRow("SELECT id FROM users WHERE LOWER(email) = LOWER($1)", req.Email).Scan(&existingUser.ID)
	if err == nil {
		return nil, errors.New("user already exists")
	}

	// Hash password
	hashedPassword, err := HashPassword(req.Password)
	if err != nil {
		return nil, err
	}

	// Create user
	user := &models.User{
		ID:           uuid.New(),
		Email:        req.Email,
		PasswordHash: hashedPassword,
		FirstName:    req.FirstName,
		LastName:     req.LastName,
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	_, err = db.Exec(`
		INSERT INTO users (id, email, password_hash, first_name, last_name, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		user.ID, user.Email, user.PasswordHash, user.FirstName, user.LastName, user.IsActive, user.CreatedAt, user.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return user, nil
}

func LoginUser(db *sql.DB, req models.UserLogin) (*models.User, string, error) {
	// Normalize email
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	var user models.User
	err := db.QueryRow(`
		SELECT id, email, password_hash, first_name, last_name, is_active, created_at, updated_at
		FROM users WHERE LOWER(email) = LOWER($1) AND is_active = true`,
		req.Email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, "", errors.New("invalid credentials")
		}
		return nil, "", err
	}

	if !CheckPasswordHash(req.Password, user.PasswordHash) {
		return nil, "", errors.New("invalid credentials")
	}

	token, err := GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, "", err
	}

	return &user, token, nil
}

func GetUserByID(db *sql.DB, userID uuid.UUID) (*models.User, error) {
	var user models.User
	err := db.QueryRow(`
		SELECT id, email, first_name, last_name, is_active, created_at, updated_at
		FROM users WHERE id = $1 AND is_active = true`,
		userID).Scan(
		&user.ID, &user.Email, &user.FirstName, &user.LastName,
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		return nil, err
	}

	return &user, nil
}
