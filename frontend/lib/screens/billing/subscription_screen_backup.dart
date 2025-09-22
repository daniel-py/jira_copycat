import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'payment_webview.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _pendingReference;

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Subscription'),
      ),
      body: subscriptionState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (subscriptionState.error != null && subscriptionState.plans.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading subscription',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subscriptionState.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                    onPressed: () async {
                      final notifier = ref.read(subscriptionStateProvider.notifier);
                      notifier.clearError();
                      await notifier.loadPlans();
                      await notifier.loadSubscriptionStatus();
                      if (ref.read(subscriptionStateProvider).plans.isNotEmpty) {
                        notifier.clearError();
                      }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pendingReference != null && subscriptionState.currentSubscription == null)
                        _buildPendingVerificationCard(context),
                      // Current subscription status
                      if (subscriptionState.currentSubscription != null)
                        _buildCurrentSubscriptionCard(context, subscriptionState.currentSubscription!)
                      else
                        _buildFreeTierCard(context),
                      
                      const SizedBox(height: 24),
                      
                      // Available plans
                      Text(
                        'Available Plans',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...subscriptionState.plans.map((plan) => _buildPlanCard(context, plan)),
                  const SizedBox(height: 24),
                  Text(
                    'Payment History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (subscriptionState.payments.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No payments yet', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    )
                  else
                    ...subscriptionState.payments.map(
                      (p) => Card(
                        child: ListTile(
                          leading: Icon(
                            p.status == 'success' ? Icons.check_circle : Icons.error,
                            color: p.status == 'success' ? Colors.green : Colors.red,
                          ),
                          title: Text('₦${(p.amount / 100).toStringAsFixed(0)} - ${p.status.toUpperCase()}'),
                          subtitle: Text('${p.reference}\n${p.paidAt != null ? _formatDate(p.paidAt!) : ''}'),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionStateProvider.notifier).loadPlans();
      ref.read(subscriptionStateProvider.notifier).loadSubscriptionStatus();
      ref.read(subscriptionStateProvider.notifier).loadPaymentHistory();
      _loadPendingReference();
    });
  }

  Widget _buildCurrentSubscriptionCard(BuildContext context, Subscription subscription) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Subscription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Plan', subscription.plan.toUpperCase()),
            _buildInfoRow('Status', subscription.status.toUpperCase()),
            _buildInfoRow('Amount', '₦${(subscription.amount / 100).toStringAsFixed(0)}'),
            _buildInfoRow('Currency', subscription.currency),
            _buildInfoRow('Start Date', _formatDate(subscription.startDate)),
            _buildInfoRow('End Date', _formatDate(subscription.endDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTierCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Free Tier',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You are currently using the free tier with limited features.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '• 1 board maximum\n• 10 cards maximum\n• Basic support',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.pending_actions, color: Colors.orange),
                SizedBox(width: 8),
                Text('Pending Payment Detected', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('If you completed payment in your browser, tap Verify to update your subscription.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  if (_pendingReference == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  try {
                    await ref.read(subscriptionStateProvider.notifier).verifySubscription(_pendingReference!);
                    await ref.read(subscriptionStateProvider.notifier).loadSubscriptionStatus();
                    await prefs.remove('pending_paystack_reference');
                    if (mounted) setState(() { _pendingReference = null; });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription verified successfully'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    plan.formattedPrice,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _subscribeToPlan(context, plan),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Subscribe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _loadPendingReference() async {
    final prefs = await SharedPreferences.getInstance();
    final refStr = prefs.getString('pending_paystack_reference');
    if (mounted) setState(() { _pendingReference = refStr; });
  }

  Future<void> _subscribeToPlan(BuildContext context, SubscriptionPlan plan) async {
    try {
      final paystackResponse = await ref.read(subscriptionStateProvider.notifier)
          .initializeSubscription(SubscriptionCreate(
        plan: plan.name.toLowerCase(),
        amount: plan.price,
      ));

      if (paystackResponse.status) {
        // Save pending reference in case user leaves the app
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_paystack_reference', paystackResponse.data.reference);
        setState(() { _pendingReference = paystackResponse.data.reference; });
        // Open Paystack in in-app WebView and verify on success
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              authorizationUrl: paystackResponse.data.authorizationUrl,
              reference: paystackResponse.data.reference,
            ),
          ),
        );

        if (result == true && mounted) {
          // Refresh status after successful verification
          await ref.read(subscriptionStateProvider.notifier).loadSubscriptionStatus();
          await prefs.remove('pending_paystack_reference');
          setState(() { _pendingReference = null; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${paystackResponse.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
