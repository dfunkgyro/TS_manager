// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
import 'package:track_sections_manager/screens/unified_search_screen.dart';
import 'package:track_sections_manager/screens/track_section_training_screen.dart';
import 'package:track_sections_manager/screens/activity_logger_screen.dart';
import 'package:track_sections_manager/screens/batch_entry_screen.dart';
import 'package:track_sections_manager/screens/grouping_management_screen.dart';
import 'package:track_sections_manager/screens/tsr_creation_wizard_screen.dart';
import 'package:track_sections_manager/screens/active_tsr_dashboard_screen.dart';
import 'package:track_sections_manager/screens/theme_settings_screen.dart';
import 'package:track_sections_manager/services/data_service.dart';
import 'package:track_sections_manager/services/enhanced_data_service.dart';
import 'package:track_sections_manager/services/supabase_service.dart';
import 'package:track_sections_manager/services/app_config.dart';
import 'package:track_sections_manager/services/theme_service.dart';

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
    // Initialize AppConfig first
    await AppConfig().initialize();

    // Then initialize other services
    await Future.wait([
      DataService().initialize(),
      EnhancedDataService().initialize(),
    ]);

    // Initialize Supabase (will work if credentials are configured in .env)
    try {
      await SupabaseService().initialize();
    } catch (e) {
      debugPrint('Supabase not configured or failed to initialize: $e');
      debugPrint('App will continue in offline mode');
    }
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }

  runApp(const TrackSectionsApp());
}

class TrackSectionsApp extends StatelessWidget {
  const TrackSectionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Track Sections Manager',
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.effectiveThemeMode,
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
              '/unified-search': (context) => const UnifiedSearchScreen(),
              '/track-section-training': (context) => const TrackSectionTrainingScreen(),
              '/activity-logger': (context) => const ActivityLoggerScreen(),
              '/batch-entry': (context) => const BatchEntryScreen(),
              '/grouping-management': (context) => const GroupingManagementScreen(),
              '/tsr-creation': (context) => const TSRCreationWizardScreen(),
              '/tsr-dashboard': (context) => const ActiveTSRDashboardScreen(),
              '/theme-settings': (context) => const ThemeSettingsScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
