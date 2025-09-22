class PaystackData {
  final String reference;
  final String accessCode;
  final String authorizationUrl;

  PaystackData({required this.reference, required this.accessCode, required this.authorizationUrl});

  factory PaystackData.fromJson(Map<String, dynamic> json) {
    return PaystackData(
      reference: json['reference'],
      accessCode: json['access_code'],
      authorizationUrl: json['authorization_url'],
    );
  }
}

class PaystackResponse {
  final bool status;
  final String message;
  final PaystackData data;

  PaystackResponse({required this.status, required this.message, required this.data});

  factory PaystackResponse.fromJson(Map<String, dynamic> json) {
    return PaystackResponse(
      status: json['status'],
      message: json['message'],
      data: PaystackData.fromJson(json['data']),
    );
  }
}

class Subscription {
  final String id;
  final String userId;
  final String paystackReference;
  final String plan;
  final String status;
  final int amount;
  final String currency;
  final String? authorizationCode;
  final String? customerCode;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? nextBillingDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.paystackReference,
    required this.plan,
    required this.status,
    required this.amount,
    required this.currency,
    this.authorizationCode,
    this.customerCode,
    required this.startDate,
    required this.endDate,
    this.nextBillingDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      userId: json['user_id'],
      paystackReference: json['paystack_reference'],
      plan: json['plan'],
      status: json['status'],
      amount: json['amount'],
      currency: json['currency'],
      authorizationCode: json['authorization_code'],
      customerCode: json['customer_code'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      nextBillingDate: json['next_billing_date'] != null ? DateTime.parse(json['next_billing_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'paystack_reference': paystackReference,
      'plan': plan,
      'status': status,
      'amount': amount,
      'currency': currency,
      'authorization_code': authorizationCode,
      'customer_code': customerCode,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'next_billing_date': nextBillingDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class SubscriptionCreate {
  final String plan;
  final int amount;

  SubscriptionCreate({required this.plan, required this.amount});

  Map<String, dynamic> toJson() {
    return {'plan': plan, 'amount': amount};
  }
}

class SubscriptionPlan {
  final String name;
  final String description;
  final int price;
  final String currency;
  final List<String> features;
  final int maxBoards;
  final int maxCards;

  SubscriptionPlan({
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.features,
    required this.maxBoards,
    required this.maxCards,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      name: json['name'],
      description: json['description'],
      price: json['price'],
      currency: json['currency'],
      features: List<String>.from(json['features']),
      maxBoards: json['max_boards'],
      maxCards: json['max_cards'],
    );
  }

  String get formattedPrice {
    return '₦${(price / 100).toStringAsFixed(0)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'features': features,
      'max_boards': maxBoards,
      'max_cards': maxCards,
    };
  }
}
