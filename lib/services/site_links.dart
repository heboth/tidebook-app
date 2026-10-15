import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Links til bookingsitet (privatlivspolitik og rejsebetingelser), som appen viser i en WebView.
///
/// Adressen angives i release-builds med `--dart-define=TIDEBOOK_SITE_URL=https://...`. Under udvikling
/// bruges bookingsitets dev-server (port 3000; Android-emulatoren når værtsmaskinen på 10.0.2.2).
class SiteLinks {
  SiteLinks._();

  static const _envUrl = String.fromEnvironment('TIDEBOOK_SITE_URL');

  /// Versionen af rejsebetingelserne, kunden accepterer (samme som bookingsitet).
  static const termsVersionId = 'TERMS-2026-V2';

  /// Versionen af teksten til samtykke om markedsføring.
  static const marketingConsentVersion = 'marketing-v1';

  /// Bookingsitets adresse – null i en release-build uden define (så skjules linkene).
  static String? get siteUrl {
    if (_envUrl.isNotEmpty) return _envUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (kReleaseMode) return null;
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  static Uri? _page(String view) {
    final base = siteUrl;
    return base == null ? null : Uri.parse('$base/?view=$view');
  }

  /// Privatlivspolitikken (GDPR art. 13) på bookingsitet.
  static Uri? get privacyPolicy => _page('privatliv');

  /// Rejsebetingelserne på bookingsitet.
  static Uri? get terms => _page('betingelser');
}
