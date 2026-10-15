import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/site_links.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';

/// Viser en side fra bookingsitet (fx privatlivspolitik eller rejsebetingelser) i en WebView.
class SitePageScreen extends StatefulWidget {
  final String title;
  final Uri url;

  const SitePageScreen({super.key, required this.title, required this.url});

  /// Åbner siden, hvis bookingsitets adresse er sat; ellers vises en besked.
  static void open(BuildContext context, {required String title, required Uri? url}) {
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('legal.unavailable'))));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SitePageScreen(title: title, url: url)));
  }

  static void openPrivacyPolicy(BuildContext context) =>
      open(context, title: tr('legal.privacyPolicy'), url: SiteLinks.privacyPolicy);

  static void openTerms(BuildContext context) =>
      open(context, title: tr('legal.terms'), url: SiteLinks.terms);

  @override
  State<SitePageScreen> createState() => _SitePageScreenState();
}

class _SitePageScreenState extends State<SitePageScreen> {
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
      ))
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Punkt "Privatlivspolitik" (bruges på profilen).
class PrivacyPolicyTile extends StatelessWidget {
  const PrivacyPolicyTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: const Key('privacy-policy-tile'),
        leading: const Icon(Icons.privacy_tip_outlined, color: GoNordicTheme.teal),
        title: Text(tr('legal.privacyPolicy'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(tr('legal.privacyPolicySubtitle'), style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => SitePageScreen.openPrivacyPolicy(context),
      ),
    );
  }
}
