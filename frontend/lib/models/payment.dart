class Payment {
  final String id;
  final String userId;
  final String? subscriptionId;
  final String reference;
  final int amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final String? channel;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.userId,
    this.subscriptionId,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.status,
    this.paidAt,
    this.channel,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      userId: json['user_id'],
      subscriptionId: json['subscription_id'],
      reference: json['reference'],
      amount: json['amount'],
      currency: json['currency'],
      status: json['status'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      channel: json['channel'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}




