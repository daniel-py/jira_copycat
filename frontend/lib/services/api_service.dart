import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board.dart';
import '../models/payment.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class ApiService {
  static const String devBaseUrl = 'http://localhost:8080/api';
  static const String baseUrl = 'https://backend-winter-dawn-4885.fly.dev/api';
  late final Dio _dio;
  String? _token;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Log API errors
        Logger.logApiError(
          error.requestOptions.path,
          error,
          statusCode: error.response?.statusCode,
          method: error.requestOptions.method,
          requestData: error.requestOptions.data,
        );
        
        if (error.response?.statusCode == 401) {
          // Token expired, clear it
          Logger.logWarning('Authentication token expired, clearing token', context: 'API_AUTH');
          await _clearToken();
        }
        handler.next(error);
      },
    ));
  }

  Future<Board> createBoard(BoardCreate boardCreate) async {
    try {
      await _loadToken();
      Logger.logInfo('Creating board: ${boardCreate.name}', context: 'API_BOARD');
      final response = await _dio.post('/boards', data: boardCreate.toJson());
      Logger.logInfo('Board created successfully: ${response.data['board']['id']}', context: 'API_BOARD');
      return Board.fromJson(response.data['board']);
    } catch (e, stackTrace) {
      Logger.logError('Failed to create board: ${boardCreate.name}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_BOARD');
      rethrow;
    }
  }

  Future<BoardCard> createCard(String columnId, CardCreate cardCreate) async {
    try {
      await _loadToken();
      Logger.logInfo('Creating card: ${cardCreate.title} in column: $columnId', context: 'API_CARD');
      final response = await _dio.post('/columns/$columnId/cards', data: cardCreate.toJson());
      Logger.logInfo('Card created successfully: ${response.data['card']['id']}', context: 'API_CARD');
      return BoardCard.fromJson(response.data['card']);
    } catch (e, stackTrace) {
      Logger.logError('Failed to create card: ${cardCreate.title}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_CARD');
      rethrow;
    }
  }

  Future<BoardColumn> createColumn(String boardId, ColumnCreate columnCreate) async {
    try {
      await _loadToken();
      Logger.logInfo('Creating column: ${columnCreate.name} in board: $boardId', context: 'API_COLUMN');
      final response = await _dio.post('/boards/$boardId/columns', data: columnCreate.toJson());
      Logger.logInfo('Column created successfully: ${response.data['column']['id']}', context: 'API_COLUMN');
      return BoardColumn.fromJson(response.data['column']);
    } catch (e, stackTrace) {
      Logger.logError('Failed to create column: ${columnCreate.name}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_COLUMN');
      rethrow;
    }
  }

  Future<void> deleteBoard(String boardId) async {
    try {
      await _loadToken();
      Logger.logInfo('Deleting board: $boardId', context: 'API_BOARD');
      await _dio.delete('/boards/$boardId');
      Logger.logInfo('Board deleted successfully: $boardId', context: 'API_BOARD');
    } catch (e, stackTrace) {
      Logger.logError('Failed to delete board: $boardId', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_BOARD');
      rethrow;
    }
  }

  Future<void> deleteCard(String cardId) async {
    await _loadToken();
    await _dio.delete('/cards/$cardId');
  }

  Future<void> deleteColumn(String columnId) async {
    await _loadToken();
    await _dio.delete('/columns/$columnId');
  }

  // 2FA methods
  Future<TwoFAStatus> get2FAStatus() async {
    await _loadToken();
    final response = await _dio.get('/billing/2fa-status');
    return TwoFAStatus.fromJson(response.data);
  }

  Future<Map<String, dynamic>> get2FAURL() async {
    await _loadToken();
    final response = await _dio.get('/billing/2fa-url');
    return response.data;
  }

  Future<Board> getBoard(String boardId) async {
    try {
      await _loadToken();
      Logger.logInfo('Fetching board: $boardId', context: 'API_BOARD');
      final response = await _dio.get('/boards/$boardId');
      final boardData = response.data['board'];
      if (boardData == null) {
        throw Exception('Board data not found in response');
      }
      final board = Board.fromJson(boardData);
      Logger.logInfo('Board fetched successfully: ${board.name}', context: 'API_BOARD');
      return board;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch board: $boardId', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_BOARD');
      rethrow;
    }
  }

  // Board methods
  Future<List<Board>> getBoards() async {
    try {
      await _loadToken();
      Logger.logInfo('Fetching boards', context: 'API_BOARD');
      final response = await _dio.get('/boards');
      final boardsData = response.data['boards'];
      if (boardsData == null) {
        Logger.logWarning('No boards data in response, returning empty list', context: 'API_BOARD');
        return [];
      }
      final boards = (boardsData as List)
          .map((json) => Board.fromJson(json))
          .toList();
      Logger.logInfo('Boards fetched successfully: ${boards.length} boards', context: 'API_BOARD');
      return boards;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch boards', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_BOARD');
      rethrow;
    }
  }

  // Card methods
  Future<List<BoardCard>> getCards(String columnId) async {
    try {
      await _loadToken();
      Logger.logInfo('Fetching cards for column: $columnId', context: 'API_CARD');
      final response = await _dio.get('/columns/$columnId/cards');
      final cardsData = response.data['cards'];
      if (cardsData == null) {
        Logger.logWarning('No cards data in response, returning empty list', context: 'API_CARD');
        return [];
      }
      final cards = (cardsData as List)
          .map((json) => BoardCard.fromJson(json))
          .toList();
      Logger.logInfo('Cards fetched successfully: ${cards.length} cards', context: 'API_CARD');
      return cards;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch cards for column: $columnId', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_CARD');
      rethrow;
    }
  }

  // Column methods
  Future<List<BoardColumn>> getColumns(String boardId) async {
    try {
      await _loadToken();
      Logger.logInfo('Fetching columns for board: $boardId', context: 'API_COLUMN');
      final response = await _dio.get('/boards/$boardId/columns');
      final columnsData = response.data['columns'];
      if (columnsData == null) {
        Logger.logWarning('No columns data in response, returning empty list', context: 'API_COLUMN');
        return [];
      }
      final columns = (columnsData as List)
          .map((json) => BoardColumn.fromJson(json))
          .toList();
      Logger.logInfo('Columns fetched successfully: ${columns.length} columns', context: 'API_COLUMN');
      return columns;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch columns for board: $boardId', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_COLUMN');
      rethrow;
    }
  }

  Future<List<Payment>> getPaymentHistory() async {
    await _loadToken();
    final response = await _dio.get('/billing/payments');
    final data = response.data['payments'] as List<dynamic>?;
    if (data == null) return [];
    return data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Subscription methods
  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      Logger.logInfo('Fetching subscription plans', context: 'API_BILLING');
      final response = await _dio.get('/billing/plans');
      final plansData = response.data['plans'];
      if (plansData == null) {
        Logger.logWarning('No plans data in response, returning empty list', context: 'API_BILLING');
        return [];
      }
      final plans = (plansData as List)
          .map((json) => SubscriptionPlan.fromJson(json))
          .toList();
      Logger.logInfo('Plans fetched successfully: ${plans.length} plans', context: 'API_BILLING');
      return plans;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch subscription plans', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_BILLING');
      rethrow;
    }
  }

  Future<User> getProfile() async {
    try {
      await _loadToken();
      Logger.logInfo('Fetching user profile', context: 'API_AUTH');
      final response = await _dio.get('/auth/profile');
      final userData = response.data['user'];
      if (userData == null) {
        throw Exception('User data not found in response');
      }
      final user = User.fromJson(userData);
      Logger.logInfo('User profile fetched successfully: ${user.email}', context: 'API_AUTH');
      return user;
    } catch (e, stackTrace) {
      Logger.logError('Failed to fetch user profile', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_AUTH');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    await _loadToken();
    final response = await _dio.get('/billing/status');
    return response.data;
  }

  // Auth token helpers
  Future<bool> hasToken() async {
    await _loadToken();
    return _token != null && _token!.isNotEmpty;
  }

  Future<PaystackResponse> initializeSubscription(SubscriptionCreate subscriptionCreate) async {
    try {
      await _loadToken();
      Logger.logInfo('Initializing subscription via API', context: 'API_BILLING');
      final response = await _dio.post('/billing/subscribe', data: subscriptionCreate.toJson());

      // Backend returns a simplified shape: { reference, access_code, authorization_url }
      final data = response.data as Map<String, dynamic>;
      final reference = data['reference'];
      final accessCode = data['access_code'];
      final authorizationUrl = data['authorization_url'];

      if (reference == null || accessCode == null || authorizationUrl == null) {
        Logger.logError('Invalid initialize response payload', context: 'API_BILLING');
        throw Exception('Invalid response from server');
      }

      final result = PaystackResponse(
        status: true,
        message: 'initialized',
        data: PaystackData(
          reference: reference,
          accessCode: accessCode,
          authorizationUrl: authorizationUrl,
        ),
      );

      Logger.logInfo('Subscription init success: $reference', context: 'API_BILLING');
      return result;
    } catch (e, stackTrace) {
      Logger.logError('Failed to initialize subscription', error: e, stackTrace: stackTrace, context: 'API_BILLING');
      rethrow;
    }
  }

  Future<AuthResponse> login(UserLogin login) async {
    try {
      Logger.logInfo('Attempting login for user: ${login.email}', context: 'API_AUTH');
      final response = await _dio.post('/auth/login', data: login.toJson());
      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      Logger.logInfo('Login successful for user: ${login.email}', context: 'API_AUTH');
      return authResponse;
    } catch (e, stackTrace) {
      Logger.logError('Login failed for user: ${login.email}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_AUTH');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  Future<BoardCard> moveCard(String cardId, CardMove cardMove) async {
    await _loadToken();
    final response = await _dio.put('/cards/$cardId/move', data: cardMove.toJson());
    return BoardCard.fromJson(response.data['card']);
  }

  // Authentication methods
  Future<AuthResponse> register(UserRegistration registration) async {
    try {
      Logger.logInfo('Attempting registration for user: ${registration.email}', context: 'API_AUTH');
      final response = await _dio.post('/auth/register', data: registration.toJson());
      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      Logger.logInfo('Registration successful for user: ${registration.email}', context: 'API_AUTH');
      return authResponse;
    } catch (e, stackTrace) {
      Logger.logError('Registration failed for user: ${registration.email}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'API_AUTH');
      rethrow;
    }
  }

  Future<Board> updateBoard(String boardId, Map<String, dynamic> updates) async {
    await _loadToken();
    final response = await _dio.put('/boards/$boardId', data: updates);
    return Board.fromJson(response.data['board']);
  }

  Future<BoardCard> updateCard(String cardId, Map<String, dynamic> updates) async {
    await _loadToken();
    final response = await _dio.put('/cards/$cardId', data: updates);
    return BoardCard.fromJson(response.data['card']);
  }

  Future<BoardColumn> updateColumn(String columnId, Map<String, dynamic> updates) async {
    await _loadToken();
    final response = await _dio.put('/columns/$columnId', data: updates);
    return BoardColumn.fromJson(response.data['column']);
  }

  Future<Subscription> verifySubscription(String reference) async {
    await _loadToken();
    final response = await _dio.get('/billing/verify?reference=$reference');
    return Subscription.fromJson(response.data['subscription']);
  }

  Future<void> _clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
