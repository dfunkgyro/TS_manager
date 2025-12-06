// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:track_sections_manager/screens/splash_screen.dart';
import 'package:track_sections_manager/screens/home_screen.dart';
import 'package:track_sections_manager/screens/query_screen.dart';
import 'package:track_sections_manager/screens/meterage_search_screen.dart';
import 'package:track_sections_manager/screens/lcs_search_screen.dart';
import 'package:track_sections_manager/screens/auth_screen.dart';
import 'package:track_sections_manager/screens/enhanced_query_screen.dart';
import 'package:track_sections_manager/screens/data_management_screen.dart';
import 'package:track_sections_manager/screens/lcs_ts_finder_screen.dart';
import 'package:track_sections_manager/screens/enhanced_lcs_ts_finder_screen.dart';
import 'package:track_sections_manager/screens/comprehensive_finder_screen.dart';
import 'package:track_sections_manager/services/data_service.dart';
import 'package:track_sections_manager/services/enhanced_data_service.dart';
import 'package:track_sections_manager/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize services
  try {
    await Future.wait([
      DataService().initialize(),
      EnhancedDataService().initialize(),
      // Uncomment when you have your Supabase credentials
      // SupabaseService().initialize(),
    ]);
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }

  runApp(const TrackSectionsApp());
}

class TrackSectionsApp extends StatelessWidget {
  const TrackSectionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Track Sections Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1E3A8A),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthScreen(),
        '/query': (context) => const QueryScreen(),
        '/enhanced-query': (context) => const EnhancedQueryScreen(),
        '/meterage': (context) => const MeterageSearchScreen(),
        '/lcs': (context) => const LCSSearchScreen(),
        '/data-management': (context) => const DataManagementScreen(),
        '/lcs-ts-finder': (context) => const LcsTsFinderScreen(),
        '/enhanced-lcs-ts-finder': (context) => const ComprehensiveFinderScreen(),
        '/comprehensive-finder': (context) => const ComprehensiveFinderScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}