// main.dart
import 'package:flutter/material.dart';
import 'package:track_sections_app/models/track_data.dart';
import 'package:track_sections_app/screens/home_screen.dart';
import 'package:track_sections_app/screens/query_screen.dart';
import 'package:track_sections_app/screens/meterage_search_screen.dart';
import 'package:track_sections_app/screens/lcs_search_screen.dart';
import 'package:track_sections_app/services/data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataService().initialize();
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
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        appBarTheme: const AppBarTheme(color: Color(0xFF1E3A8A)),
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/query': (context) => const QueryScreen(),
        '/meterage': (context) => const MeterageSearchScreen(),
        '/lcs': (context) => const LCSSearchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}