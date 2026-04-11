import 'package:flutter/material.dart';
import 'package:usesense_flutter/usesense_flutter.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UseSenseExampleApp());
}

/// Example app root.
///
/// The SDK is intentionally NOT initialized here. Initialization is
/// deferred to [HomeScreen], which reads an API key from a text field
/// (persisted via shared_preferences) and calls `UseSenseFlutter.initialize`
/// lazily on first Enroll/Authenticate tap. This matches the iOS
/// example's `@AppStorage("apiKey")` + `SecureField` pattern and the
/// Android example's `SharedPreferences`-backed `OutlinedTextField`
/// pattern, so integrators can clone, run, paste their key once, and
/// test without touching any source code.
class UseSenseExampleApp extends StatelessWidget {
  const UseSenseExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UseSense Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F7CFF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F7CFF),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(useSense: UseSenseFlutter()),
    );
  }
}
