// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:track_sections_manager/widgets/navigation_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Sections Manager'),
        backgroundColor: Colors.blue,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AboutDialog(),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Railway Track Sections',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'LCS Code & Meterage Management System',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.2,
                  children: [
                    NavigationCard(
                      title: 'Meterage Search',
                      subtitle: 'Find by meterage value',
                      icon: Icons.speed,
                      color: Colors.green,
                      onTap: () {
                        Navigator.pushNamed(context, '/meterage');
                      },
                    ),
                    NavigationCard(
                      title: 'LCS Code Search',
                      subtitle: 'Find by LCS Code',
                      icon: Icons.qr_code,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pushNamed(context, '/lcs');
                      },
                    ),
                    NavigationCard(
                      title: 'Advanced Query',
                      subtitle: 'Combined search options',
                      icon: Icons.search,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pushNamed(context, '/query');
                      },
                    ),
                    NavigationCard(
                      title: 'LCS/TS Finder',
                      subtitle: 'Find by LCS or Platform',
                      icon: Icons.find_in_page,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.pushNamed(context, '/enhanced-lcs-ts-finder');
                      },
                    ),
                    NavigationCard(
                      title: 'Data Export',
                      subtitle: 'Export results',
                      icon: Icons.download,
                      color: Colors.red,
                      onTap: () {
                        _showExportDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter meterage values or LCS codes to find corresponding track sections and nearest locations',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Select export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Export functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data exported successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Export CSV'),
          ),
          ElevatedButton(
            onPressed: () {
              // Export functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data exported successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }
}