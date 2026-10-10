import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/gonordic_theme.dart';
import '../services/texts_service.dart';

/// Nets' betalingsside (Hosted Payment Page) i en WebView.
///
/// Core opretter betalingen og giver appen sidens adresse samt en retur- og en afbrudt-adresse.
/// Kunden betaler hos Nets (kort, MobilePay); når Nets sender kunden til retur-adressen, lukkes
/// skærmen med `true`, ved afbrudt med `false`. Selve bekræftelsen sker derefter hos Core (/complete).
/// I test viser Core en simulator-side med testkort – appen behandler den på samme måde.
class NetsPaymentScreen extends StatefulWidget {
  final String paymentPageUrl;
  final String returnUrl;
  final String cancelUrl;
  final String pnr;

  const NetsPaymentScreen({
    super.key,
    required this.paymentPageUrl,
    required this.returnUrl,
    required this.cancelUrl,
    required this.pnr,
  });

  @override
  State<NetsPaymentScreen> createState() => _NetsPaymentScreenState();
}

class _NetsPaymentScreenState extends State<NetsPaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  void _finish(bool paid) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(paid);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (request.url.startsWith(widget.returnUrl)) {
              _finish(true);
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(widget.cancelUrl)) {
              _finish(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentPageUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(false);
      },
      child: Scaffold(
        backgroundColor: GoNordicTheme.sand,
        appBar: AppBar(
          title: Text(tr('netsPayment.title', {'pnr': widget.pnr})),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: tr('netsPayment.cancelTooltip'),
            onPressed: () => _finish(false),
          ),
          bottom: _loading
              ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
              : null,
        ),
        body: SafeArea(child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
