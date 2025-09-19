# Error Logging Implementation

This document describes the comprehensive error logging system implemented in the Jira Copycat frontend application.

## Overview

The application now includes detailed error logging that captures both API errors and application-level errors, providing better debugging capabilities and error tracking.

## Components

### 1. Logger Utility (`lib/utils/logger.dart`)

A centralized logging utility that provides different log levels and contexts:

- **Error Logging**: `Logger.logError()` - For errors with stack traces
- **Info Logging**: `Logger.logInfo()` - For informational messages
- **Warning Logging**: `Logger.logWarning()` - For warning messages
- **API Error Logging**: `Logger.logApiError()` - Specialized for API errors

### 2. API Service Logging (`lib/services/api_service.dart`)

All API methods now include:
- **Request logging**: Logs when API calls are initiated
- **Success logging**: Logs successful API responses
- **Error logging**: Comprehensive error logging with context
- **Interceptor logging**: Automatic logging of all API errors via Dio interceptors

### 3. Provider Logging

All state management providers include error logging:
- **AuthProvider**: Login, registration, and authentication status checks
- **BoardProvider**: Board operations, card management, column operations
- **SubscriptionProvider**: Subscription management and billing operations

## Log Levels

- **ERROR (1000)**: Critical errors that need immediate attention
- **WARNING (900)**: Warnings that should be noted
- **INFO (800)**: General informational messages

## Context Tags

Each log entry includes a context tag for easy filtering:
- `API_AUTH`: Authentication-related API calls
- `API_BOARD`: Board management API calls
- `API_CARD`: Card management API calls
- `API_COLUMN`: Column management API calls
- `AUTH_PROVIDER`: Authentication state management
- `BOARD_PROVIDER`: Board state management
- `SUBSCRIPTION_PROVIDER`: Subscription state management

## Usage Examples

### Basic Error Logging
```dart
try {
  // Some operation
} catch (e, stackTrace) {
  Logger.logError('Operation failed', 
    error: e, 
    stackTrace: stackTrace, 
    context: 'MY_CONTEXT');
}
```

### API Error Logging
```dart
Logger.logApiError(
  '/api/endpoint',
  error,
  statusCode: 404,
  method: 'GET',
  requestData: {'key': 'value'},
);
```

### Info Logging
```dart
Logger.logInfo('User logged in successfully', context: 'AUTH');
```

## Benefits

1. **Better Debugging**: Detailed error information with stack traces
2. **Context Awareness**: Each log includes relevant context
3. **API Monitoring**: Automatic logging of all API errors
4. **Performance Tracking**: Logs include timing and success/failure information
5. **Development Aid**: Console output for immediate visibility during development

## Console Output

In debug mode, all logs are printed to the console with the format:
```
ERROR [CONTEXT]: Message
Error details: [error details]
Stack trace: [stack trace]
```

## Production Considerations

- Logs are only output in debug mode (`kDebugMode`)
- In production, logs are sent to the developer console
- Consider implementing a crash reporting service for production error tracking
