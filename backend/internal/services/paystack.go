package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"jira-copycat-backend/internal/config"
	"jira-copycat-backend/internal/models"
)

type PaystackService struct {
	SecretKey string
	BaseURL   string
}

func NewPaystackService() *PaystackService {
	return &PaystackService{
		SecretKey: config.GetRequiredEnv("PAYSTACK_SECRET_KEY"),
		BaseURL:   "https://api.paystack.co",
	}
}

func (p *PaystackService) InitializeTransaction(email string, amount int, plan string) (*models.PaystackResponse, error) {
	url := fmt.Sprintf("%s/transaction/initialize", p.BaseURL)
	
	payload := map[string]interface{}{
		"email":  email,
		"amount": amount,
		"metadata": map[string]interface{}{
			"plan": plan,
		},
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+p.SecretKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var paystackResp models.PaystackResponse
	if err := json.Unmarshal(body, &paystackResp); err != nil {
		return nil, err
	}

	return &paystackResp, nil
}

func (p *PaystackService) VerifyTransaction(reference string) (*models.PaystackVerifyResponse, error) {
	url := fmt.Sprintf("%s/transaction/verify/%s", p.BaseURL, reference)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+p.SecretKey)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var paystackResp models.PaystackVerifyResponse
	if err := json.Unmarshal(body, &paystackResp); err != nil {
		return nil, err
	}

	return &paystackResp, nil
}

func (p *PaystackService) GetSubscriptionPlans() []models.SubscriptionPlan {
	return []models.SubscriptionPlan{
		{
			Name:        "Basic",
			Description: "Perfect for individuals and small teams",
			Price:       500000, // 5000 NGN in kobo
			Currency:    "NGN",
			Features: []string{
				"Up to 3 boards",
				"Up to 50 cards per board",
				"Basic support",
			},
			MaxBoards: 3,
			MaxCards:  50,
		},
		{
			Name:        "Pro",
			Description: "Ideal for growing teams",
			Price:       1500000, // 15000 NGN in kobo
			Currency:    "NGN",
			Features: []string{
				"Unlimited boards",
				"Unlimited cards",
				"Priority support",
				"Advanced analytics",
			},
			MaxBoards: -1, // Unlimited
			MaxCards:  -1, // Unlimited
		},
		{
			Name:        "Enterprise",
			Description: "For large organizations",
			Price:       5000000, // 50000 NGN in kobo
			Currency:    "NGN",
			Features: []string{
				"Everything in Pro",
				"Custom integrations",
				"Dedicated support",
				"Advanced security",
			},
			MaxBoards: -1, // Unlimited
			MaxCards:  -1, // Unlimited
		},
	}
}

type chargeAuthRequest struct {
    Email             string `json:"email"`
    Amount            int    `json:"amount"`
    AuthorizationCode string `json:"authorization_code"`
}

type chargeAuthResponse struct {
    Status  bool   `json:"status"`
    Message string `json:"message"`
    Data    struct {
        Reference string `json:"reference"`
        Status    string `json:"status"`
        Amount    int    `json:"amount"`
        Currency  string `json:"currency"`
    } `json:"data"`
}

func (p *PaystackService) ChargeAuthorization(email string, amount int, authorizationCode string) (*chargeAuthResponse, error) {
    url := fmt.Sprintf("%s/transaction/charge_authorization", p.BaseURL)

    payload := chargeAuthRequest{
        Email:             email,
        Amount:            amount,
        AuthorizationCode: authorizationCode,
    }

    jsonData, err := json.Marshal(payload)
    if err != nil {
        return nil, err
    }

    req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
    if err != nil {
        return nil, err
    }

    req.Header.Set("Authorization", "Bearer "+p.SecretKey)
    req.Header.Set("Content-Type", "application/json")

    client := &http.Client{Timeout: 30 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, err
    }

    var res chargeAuthResponse
    if err := json.Unmarshal(body, &res); err != nil {
        return nil, err
    }

    return &res, nil
}
