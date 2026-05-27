import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'providers/sync_providers.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Resolve Application Documents directory for local Mock Drive usage
  final directory = await getApplicationDocumentsDirectory();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDocumentsDirProvider.overrideWithValue(directory.path),
      ],
      child: const SyncGoApp(),
    ),
  );
}

class SyncGoApp extends StatelessWidget {
  const SyncGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SynGo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6CBE83), // Glowing Mint
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6CBE83),
          secondary: Color(0xFF6CBE83),
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
        ),
        // Premium transparent bottom sheets, etc.
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
