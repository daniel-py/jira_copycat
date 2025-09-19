# Jira Copycat - Setup Guide

## Overview

This is a lightweight Jira copycat built with:
- **Frontend**: Flutter with Riverpod state management
- **Backend**: Golang with Gin framework
- **Database**: PostgreSQL
- **Billing**: Paystack integration
- **Deployment**: Docker

## Features

✅ **Kanban Board**: Create boards, columns, and cards with drag-and-drop functionality  
✅ **User Authentication**: Registration, login, and JWT-based auth  
✅ **Subscription Billing**: Paystack integration with multiple plans  
✅ **Real-time Updates**: Live updates when team members make changes  
✅ **Responsive Design**: Works on mobile and desktop  
✅ **Free Tier**: 1 board, 10 cards for free users  

## Prerequisites

- Docker and Docker Compose
- FVM (Flutter Version Manager) - for Flutter development
- Go 1.21+ (if running backend locally)
- PostgreSQL (if running database locally)

## Quick Start with Docker

1. **Clone and navigate to the project**:
   ```bash
   cd jira_copycat
   ```

2. **Set up environment variables**:
   ```bash
   cp backend/env.example backend/.env
   # Edit backend/.env with your Paystack keys
   ```

3. **Start the services**:
   ```bash
   docker-compose up -d
   ```

4. **Access the application**:
   - Backend API: http://localhost:8080
   - Database: localhost:5432

## Flutter Development Setup

1. **Navigate to frontend directory**:
   ```bash
   cd frontend
   ```

2. **Use FVM to manage Flutter version**:
   ```bash
   fvm use 3.32.6
   ```

3. **Install dependencies**:
   ```bash
   fvm flutter pub get
   ```

4. **Run the Flutter app**:
   ```bash
   fvm flutter run
   ```

## Backend Development Setup

1. **Navigate to backend directory**:
   ```bash
   cd backend
   ```

2. **Install dependencies**:
   ```bash
   go mod tidy
   ```

3. **Set up environment variables**:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

4. **Run the backend**:
   ```bash
   go run main.go
   ```

## Environment Configuration

### Backend (.env)
```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=jira_copycat

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Paystack Configuration
PAYSTACK_SECRET_KEY=sk_test_your_paystack_secret_key
PAYSTACK_PUBLIC_KEY=pk_test_your_paystack_public_key

# Server Configuration
PORT=8080
GIN_MODE=debug
```

### Flutter (lib/services/api_service.dart)
Update the `baseUrl` in `ApiService` to match your backend URL:
```dart
static const String baseUrl = 'http://localhost:8080/api';
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/profile` - Get user profile

### Boards
- `GET /api/boards` - Get user's boards
- `POST /api/boards` - Create new board
- `GET /api/boards/:id` - Get board details
- `PUT /api/boards/:id` - Update board
- `DELETE /api/boards/:id` - Delete board

### Columns
- `GET /api/boards/:id/columns` - Get board columns
- `POST /api/boards/:id/columns` - Create column
- `PUT /api/columns/:id` - Update column
- `DELETE /api/columns/:id` - Delete column

### Cards
- `GET /api/columns/:id/cards` - Get column cards
- `POST /api/columns/:id/cards` - Create card
- `PUT /api/cards/:id` - Update card
- `PUT /api/cards/:id/move` - Move card between columns
- `DELETE /api/cards/:id` - Delete card

### Billing
- `GET /api/billing/plans` - Get subscription plans
- `POST /api/billing/subscribe` - Initialize subscription
- `GET /api/billing/verify` - Verify payment
- `GET /api/billing/status` - Get subscription status
- `POST /api/billing/webhook` - Paystack webhook

## Subscription Plans

### Free Tier
- 1 board maximum
- 10 cards maximum
- Basic support

### Basic Plan - ₦5,000/month
- Up to 3 boards
- Up to 50 cards per board
- Basic support

### Pro Plan - ₦15,000/month
- Unlimited boards
- Unlimited cards
- Priority support
- Advanced analytics

### Enterprise Plan - ₦50,000/month
- Everything in Pro
- Custom integrations
- Dedicated support
- Advanced security

## Database Schema

The application uses PostgreSQL with the following main tables:
- `users` - User accounts and authentication
- `boards` - Kanban boards
- `columns` - Board columns
- `cards` - Task cards
- `subscriptions` - User subscription data

## Development Notes

### Flutter Architecture
- **State Management**: Riverpod for reactive state management
- **API Layer**: Dio for HTTP requests with interceptors
- **Models**: Data classes with JSON serialization
- **Providers**: Separate providers for auth, boards, and subscriptions

### Backend Architecture
- **Framework**: Gin for HTTP routing
- **Database**: PostgreSQL with raw SQL queries
- **Authentication**: JWT tokens
- **Billing**: Paystack API integration
- **Middleware**: CORS, authentication, error handling

### Key Features Implemented
1. **Drag and Drop**: Cards can be moved between columns
2. **Real-time Updates**: State updates reflect immediately in UI
3. **Subscription Limits**: Free tier restrictions enforced
4. **Payment Integration**: Paystack payment flow
5. **Responsive Design**: Works on mobile and desktop
6. **Error Handling**: Comprehensive error states and user feedback

## Troubleshooting

### Common Issues

1. **Database Connection Error**:
   - Ensure PostgreSQL is running
   - Check database credentials in .env
   - Verify database exists

2. **Flutter Build Errors**:
   - Run `fvm flutter clean`
   - Run `fvm flutter pub get`
   - Check Flutter version compatibility

3. **API Connection Issues**:
   - Verify backend is running on port 8080
   - Check CORS settings
   - Update API base URL in Flutter

4. **Paystack Integration**:
   - Ensure you're using test keys for development
   - Check webhook URL configuration
   - Verify payment callback handling

## Production Deployment

1. **Update environment variables** with production values
2. **Configure proper JWT secrets** and database credentials
3. **Set up SSL certificates** for HTTPS
4. **Configure Paystack production keys**
5. **Set up monitoring and logging**
6. **Configure backup strategies** for the database

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is for educational purposes. Please ensure you comply with all applicable licenses and terms of service for the technologies used.
