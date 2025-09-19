# Jira Copycat - Lightweight Kanban Board

A lightweight Jira copycat built with Flutter frontend and Golang backend, featuring:
- Kanban board functionality
- Paystack subscription billing integration
- User authentication
- Real-time updates

## Project Structure

```
jira_copycat/
├── backend/          # Golang REST API
├── frontend/         # Flutter mobile app
├── docker-compose.yml
└── README.md
```

## Features

- **Kanban Board**: Create boards, columns, and cards with drag-and-drop functionality
- **User Management**: Registration, login, and profile management
- **Subscription Billing**: Paystack integration for monthly/yearly subscriptions
- **Real-time Updates**: Live updates when team members make changes
- **Responsive Design**: Works on mobile and desktop

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Golang with Gin framework
- **Database**: PostgreSQL
- **Authentication**: JWT tokens
- **Billing**: Paystack API
- **Deployment**: Docker


## API Endpoints

- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/boards` - Get user's boards
- `POST /api/boards` - Create new board
- `PUT /api/boards/:id` - Update board
- `DELETE /api/boards/:id` - Delete board
- `GET /api/boards/:id/columns` - Get board columns
- `POST /api/boards/:id/columns` - Create column
- `PUT /api/columns/:id` - Update column
- `DELETE /api/columns/:id` - Delete column
- `GET /api/columns/:id/cards` - Get column cards
- `POST /api/columns/:id/cards` - Create card
- `PUT /api/cards/:id` - Update card
- `DELETE /api/cards/:id` - Delete card
- `POST /api/billing/subscribe` - Create subscription
- `GET /api/billing/status` - Get subscription status
