import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'theme/gonordic_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'Go Nordic Cruiseline • Tidebook',
      debugShowCheckedModeBanner: false,
      theme: GoNordicTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

