import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Links til bookingsitet (privatlivspolitik og rejsebetingelser), som appen viser i en WebView.
///
/// Standard: bookingsitet online (tidebook.ceniconsulting.dk). `--dart-define=TIDEBOOK_SITE_URL=local` bruger
/// bookingsitets dev-server (port 3000; Android-emulatoren når værtsmaskinen på 10.0.2.2); en anden adresse kan
/// også angives. Siderne åbnes indlejret (`embed=1`): kun teksten, og online uden det fælles login.
class SiteLinks {
  SiteLinks._();

  static const defaultUrl = 'https://tidebook.ceniconsulting.dk';
  static const _envUrl = String.fromEnvironment('TIDEBOOK_SITE_URL', defaultValue: defaultUrl);
  static bool get _local => _envUrl.trim() == 'local';

  /// Versionen af rejsebetingelserne, kunden accepterer (samme som bookingsitet).
  static const termsVersionId = 'TERMS-2026-V2';

  /// Versionen af teksten til samtykke om markedsføring.
  static const marketingConsentVersion = 'marketing-v1';

  /// Bookingsitets adresse – null i en release-build med `local` (så skjules linkene).
  static String? get siteUrl {
    if (_envUrl.isNotEmpty && !_local) return _envUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (kReleaseMode) return null;
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}
    return 'http://localhost:3000';
  }

  static Uri? _page(String view) {
    final base = siteUrl;
    return base == null ? null : Uri.parse('$base/?view=$view&embed=1');
  }

  /// Privatlivspolitikken (GDPR art. 13) på bookingsitet.
  static Uri? get privacyPolicy => _page('privatliv');

  /// Rejsebetingelserne på bookingsitet.
  static Uri? get terms => _page('betingelser');
}
