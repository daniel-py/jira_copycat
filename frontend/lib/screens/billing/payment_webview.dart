import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/subscription_provider.dart';
import '../../utils/logger.dart';

class PaymentWebView extends ConsumerStatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaymentWebView({super.key, required this.authorizationUrl, required this.reference});

  @override
  ConsumerState<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends ConsumerState<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _verificationTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          TextButton(
            onPressed: _verifyOnce,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    Logger.logInfo('Loading Paystack URL: ${widget.authorizationUrl}', context: 'WEBVIEW');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) '
        'Version/14.0 Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            Logger.logInfo('onPageStarted: $url', context: 'WEBVIEW');
            setState(() => _isLoading = true);
          },
          onUrlChange: (change) {
            final url = change.url ?? '';
            Logger.logInfo('onUrlChange: $url', context: 'WEBVIEW');
          },
          onPageFinished: (url) async {
            Logger.logInfo('onPageFinished: $url', context: 'WEBVIEW');
            setState(() => _isLoading = false);

            // Heuristics to detect completion
            if (_shouldVerifyFromUrl(url)) {
              await _verifyOnce();
              return;
            }

            // Try to detect success text within the page
            try {
              final js = "document.body ? document.body.innerText.toLowerCase() : ''";
              final result = await _controller.runJavaScriptReturningResult(js);
              final bodyText = _asString(result).toLowerCase();
              if (bodyText.contains('payment successful') ||
                  bodyText.contains('payment completed') ||
                  bodyText.contains('transaction successful') ||
                  bodyText.contains('transaction complete')) {
                await _verifyOnce();
              }
            } catch (e, st) {
              Logger.logError('JS detection failed', error: e, stackTrace: st, context: 'WEBVIEW');
            }
          },
          onHttpError: (error) {
            Logger.logError('HTTP error: ${error.response?.statusCode} on ${error.response?.uri}', context: 'WEBVIEW');
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load payment page (${error.response?.statusCode}).')),
              );
            }
          },
          onWebResourceError: (error) {
            Logger.logError('Resource error: ${error.errorType} - ${error.description}', context: 'WEBVIEW');
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading page: ${error.description}')),
              );
            }
          },
          onNavigationRequest: (request) {
            Logger.logInfo('onNavigationRequest: ${request.url}', context: 'WEBVIEW');
            // Intercept close or callback redirects
            if (_shouldVerifyFromUrl(request.url)) {
              _verifyOnce();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  String _asString(Object? value) {
    if (value == null) return '';
    // WebView JS returns value wrapped in quotes sometimes
    final s = value.toString();
    return s.startsWith('"') && s.endsWith('"') ? s.substring(1, s.length - 1) : s;
  }

  bool _shouldVerifyFromUrl(String url) {
    final lower = url.toLowerCase();
    // Paystack often redirects to /close or a callback with reference
    return lower.contains('/close') || lower.contains('reference=') || lower.contains('/callback');
  }

  Future<void> _verifyOnce() async {
    if (_verificationTriggered) return;
    _verificationTriggered = true;
    try {
      Logger.logInfo('Verifying reference: ${widget.reference}', context: 'WEBVIEW');
      await ref.read(subscriptionStateProvider.notifier).verifySubscription(widget.reference);
      await ref.read(subscriptionStateProvider.notifier).loadSubscriptionStatus();
      await ref.read(subscriptionStateProvider.notifier).loadPaymentHistory();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      Logger.logError('Verification failed', error: e, stackTrace: st, context: 'WEBVIEW');
      if (mounted) Navigator.of(context).pop(false);
    }
  }
}
