import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class Logger {
  static const String _tag = 'JiraCopycat';

  static void logApiError(
    String endpoint,
    dynamic error, {
    int? statusCode,
    String? method,
    Map<String, dynamic>? requestData,
  }) {
    final context = 'API_${method ?? 'REQUEST'}';
    final message = 'API call failed: $endpoint';
    
    Logger.logError(
      message,
      error: error,
      context: context,
    );
    
    if (statusCode != null) {
      Logger.logError('Status code: $statusCode', context: context);
    }
    
    if (requestData != null) {
      Logger.logError('Request data: $requestData', context: context);
    }
  }

  static void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? context,
  }) {
    final errorMessage = context != null ? '[$context] $message' : message;
    
    if (kDebugMode) {
      developer.log(
        errorMessage,
        name: _tag,
        error: error,
        stackTrace: stackTrace,
        level: 1000, // Error level
      );
    }
    
    // Also print to console for immediate visibility
    print('ERROR [$context]: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
  }

  static void logInfo(String message, {String? context}) {
    final infoMessage = context != null ? '[$context] $message' : message;
    
    if (kDebugMode) {
      developer.log(
        infoMessage,
        name: _tag,
        level: 800, // Info level
      );
    }
    
    print('INFO [$context]: $message');
  }

  static void logWarning(String message, {String? context}) {
    final warningMessage = context != null ? '[$context] $message' : message;
    
    if (kDebugMode) {
      developer.log(
        warningMessage,
        name: _tag,
        level: 900, // Warning level
      );
    }
    
    print('WARNING [$context]: $message');
  }
}
