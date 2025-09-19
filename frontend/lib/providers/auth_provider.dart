import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(AuthState()) {
    _checkAuthStatus();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> login(UserLogin login) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Starting login process for user: ${login.email}', context: 'AUTH_PROVIDER');
      final authResponse = await _apiService.login(login);
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      Logger.logInfo('Login process completed successfully for user: ${login.email}', context: 'AUTH_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Login process failed for user: ${login.email}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'AUTH_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    state = AuthState();
  }

  Future<void> register(UserRegistration registration) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Starting registration process for user: ${registration.email}', context: 'AUTH_PROVIDER');
      final authResponse = await _apiService.register(registration);
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      Logger.logInfo('Registration process completed successfully for user: ${registration.email}', context: 'AUTH_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Registration process failed for user: ${registration.email}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'AUTH_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      Logger.logInfo('Checking authentication status', context: 'AUTH_PROVIDER');
      final user = await _apiService.getProfile();
      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      );
      Logger.logInfo('Authentication status check successful for user: ${user.email}', context: 'AUTH_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Authentication status check failed', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'AUTH_PROVIDER');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
