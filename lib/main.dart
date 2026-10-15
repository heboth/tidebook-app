import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/booking_service.dart';
import 'services/texts_service.dart';
import 'services/token_store.dart';
import 'theme/gonordic_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Indbyggede tekster med det samme; TideCMS hentes i baggrunden og lægges ovenpå
  await TextsService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // En release-build må ikke pege på udviklingsmaskinen (TIDEBOOK_API_URL/TIDECMS_URL=local)
  final missing = missingReleaseDefines();
  if (missing.isNotEmpty) {
    runApp(ConfigErrorApp(missing: missing));
    return;
  }

  // Bookinger hentes fra Core med de gemte booking-nøgler; ruterne hentes også fra Core
  BookingService().init(tokenStore: SecureBookingTokenStore());
  runApp(const TidebookApp());
}

/// De --dart-define-værdier, der mangler i en release-build (tom i debug/profile).
List<String> missingReleaseDefines({bool releaseMode = kReleaseMode}) => [
      if (!ApiService.isConfigured(releaseMode: releaseMode)) 'TIDEBOOK_API_URL',
      if (!TextsService.isConfigured(releaseMode: releaseMode)) 'TIDECMS_URL',
    ];

/// Vises i stedet for appen, når en release-build mangler sin konfiguration.
class ConfigErrorApp extends StatelessWidget {
  final List<String> missing;
  const ConfigErrorApp({super.key, required this.missing});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GoNordicTheme.lightTheme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: GoNordicTheme.error),
                const SizedBox(height: 12),
                Text(tr('config.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(tr('config.body', {'keys': missing.join(', ')}), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TidebookApp extends StatelessWidget {
  const TidebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Genopbygges, når teksterne fra TideCMS er hentet eller sproget skiftes
    return ValueListenableBuilder<int>(
      valueListenable: TextsService.instance.revision,
      builder: (context, revision, child) => MaterialApp(
        key: ValueKey(TextsService.instance.revision.value),
        title: 'Go Nordic Cruiseline • Tidebook',
        debugShowCheckedModeBanner: false,
        theme: GoNordicTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
