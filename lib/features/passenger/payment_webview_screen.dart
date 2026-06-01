import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String bookingId;
  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.bookingId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _State();
}

class _State extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final url = request.url;
          // Intercept GeniusPay redirect back to our app
          if (url.contains('/passenger/payment/success')) {
            context.go('/passenger/payment/success/${widget.bookingId}');
            return NavigationDecision.prevent;
          }
          if (url.contains('/passenger/payment/error')) {
            context.go('/passenger/payment/error/${widget.bookingId}');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentSecureTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () =>
              context.go('/passenger/payment/error/${widget.bookingId}'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.reload,
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: brandOrange),
              const SizedBox(height: 12),
              Text(l10n.paymentLoadingWebview,
                  style: TextStyle(color: context.textSecondary, fontSize: 13)),
            ]),
          ),
      ]),
    );
  }
}
