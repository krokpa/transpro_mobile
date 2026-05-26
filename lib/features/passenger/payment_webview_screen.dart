import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Annuler',
          onPressed: () =>
              context.go('/passenger/payment/error/${widget.bookingId}'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: brandOrange),
              SizedBox(height: 12),
              Text('Chargement du paiement…',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ]),
          ),
      ]),
    );
  }
}
