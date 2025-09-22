import 'package:flutter_riverpod/legacy.dart';
import 'package:jira_copycat/providers/auth_provider.dart';

import '../models/payment.dart';
import '../models/subscription.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

final subscriptionStateProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.read(apiServiceProvider));
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final ApiService _apiService;

  SubscriptionNotifier(this._apiService) : super(SubscriptionState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<PaystackResponse> initializeSubscription(SubscriptionCreate subscriptionCreate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Initializing subscription for plan: ${subscriptionCreate.plan}', context: 'SUBSCRIPTION_PROVIDER');
      final response = await _apiService.initializeSubscription(subscriptionCreate);
      state = state.copyWith(isLoading: false);
      Logger.logInfo('Subscription initialized successfully: ${response.data.reference}', context: 'SUBSCRIPTION_PROVIDER');
      return response;
    } catch (e, stackTrace) {
      Logger.logError('Failed to initialize subscription for plan: ${subscriptionCreate.plan}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'SUBSCRIPTION_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> loadPaymentHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Loading payment history', context: 'SUBSCRIPTION_PROVIDER');
      final payments = await _apiService.getPaymentHistory();
      state = state.copyWith(payments: payments, isLoading: false);
      Logger.logInfo('Payment history loaded: ${payments.length} items', context: 'SUBSCRIPTION_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError(
        'Failed to load payment history',
        error: e,
        stackTrace: stackTrace,
        context: 'SUBSCRIPTION_PROVIDER',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Loading subscription plans', context: 'SUBSCRIPTION_PROVIDER');
      final plans = await _apiService.getPlans();
      state = state.copyWith(
        plans: plans,
        isLoading: false,
      );
      Logger.logInfo('Subscription plans loaded successfully: ${plans.length} plans found', context: 'SUBSCRIPTION_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Failed to load subscription plans', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'SUBSCRIPTION_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadSubscriptionStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Loading subscription status', context: 'SUBSCRIPTION_PROVIDER');
      final response = await _apiService.getSubscriptionStatus();
      if (response['has_subscription'] == true) {
        final subscription = Subscription.fromJson(response['subscription']);
        state = state.copyWith(
          currentSubscription: subscription,
          isLoading: false,
        );
        Logger.logInfo('Subscription status loaded: Active subscription found', context: 'SUBSCRIPTION_PROVIDER');
      } else {
        state = state.copyWith(
          currentSubscription: null,
          isLoading: false,
        );
        Logger.logInfo('Subscription status loaded: No active subscription', context: 'SUBSCRIPTION_PROVIDER');
      }
    } catch (e, stackTrace) {
      Logger.logError('Failed to load subscription status', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'SUBSCRIPTION_PROVIDER');
      
      // Check if it's an authentication error
      String errorMessage = e.toString();
      if (e.toString().contains('401')) {
        errorMessage = 'Authentication required. Please log in again.';
        Logger.logWarning('Authentication error detected in loadSubscriptionStatus', context: 'SUBSCRIPTION_PROVIDER');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  Future<void> verifySubscription(String reference) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final subscription = await _apiService.verifySubscription(reference);
      state = state.copyWith(
        currentSubscription: subscription,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class SubscriptionState {
  final List<SubscriptionPlan> plans;
  final Subscription? currentSubscription;
  final List<Payment> payments;
  final bool isLoading;
  final String? error;

  SubscriptionState({
    this.plans = const [],
    this.currentSubscription,
    this.payments = const [],
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    List<SubscriptionPlan>? plans,
    Subscription? currentSubscription,
    List<Payment>? payments,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      plans: plans ?? this.plans,
      currentSubscription: currentSubscription ?? this.currentSubscription,
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

 
