import 'package:flutter/material.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UseSenseExampleApp());
}

/// Brand manual color palette.
abstract final class UseSenseColors {
  static const blue5 = Color(0xFF4F7CFF);
  static const blue6 = Color(0xFF3D63DB);
  static const blue7 = Color(0xFF2C4AB7);
  static const blue0 = Color(0xFFEBF0FF);
  static const purple5 = Color(0xFF7C5CFC);
  static const green5 = Color(0xFF00D4AA);
  static const green7 = Color(0xFF008066);
  static const green0 = Color(0xFFE6FBF5);
  static const red5 = Color(0xFFFF6B4A);
  static const red0 = Color(0xFFFFF0EC);
  static const warm5 = Color(0xFFFFB84D);
  static const warm0 = Color(0xFFFFF7E8);
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFFDFCFA);
  static const neutral1 = Color(0xFFF5F3EF);
  static const neutral2 = Color(0xFFE8E5DE);
  static const neutral4 = Color(0xFF9E9A92);
  static const neutral5 = Color(0xFF6B6760);
  static const neutral6 = Color(0xFF3D3A35);
  static const neutral7 = Color(0xFF2A2723);
  static const neutral8 = Color(0xFF1C1A17);
}

class UseSenseExampleApp extends StatefulWidget {
  const UseSenseExampleApp({super.key});

  @override
  State<UseSenseExampleApp> createState() => _UseSenseExampleAppState();
}

class _UseSenseExampleAppState extends State<UseSenseExampleApp> {
  final _useSense = UseSenseFlutter();
  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initSdk();
  }

  Future<void> _initSdk() async {
    try {
      await _useSense.initialize(
        const UseSenseConfig(
          // TODO: Replace with your sandbox API key from https://app.usesense.ai
          apiKey: 'pk_sandbox_YOUR_API_KEY',
          environment: UseSenseEnvironment.sandbox,
        ),
      );
      setState(() => _initialized = true);
    } on UseSenseError catch (e) {
      setState(() => _initError = e.message);
    }
  }

  @override
  void dispose() {
    _useSense.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UseSense Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: UseSenseColors.blue5,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: UseSenseColors.neutral50,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: UseSenseColors.neutral2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: UseSenseColors.blue5,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: UseSenseColors.neutral8,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: UseSenseColors.neutral6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: HomeScreen(
        useSense: _useSense,
        initialized: _initialized,
        initError: _initError,
      ),
    );
  }
}
