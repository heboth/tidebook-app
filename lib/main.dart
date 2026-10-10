import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/texts_service.dart';
import 'theme/gonordic_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Indbyggede tekster med det samme; TideCMS hentes i baggrunden og lægges ovenpå
  await TextsService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const TidebookApp());
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

