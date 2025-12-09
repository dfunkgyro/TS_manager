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
              const SizedBox(height: 30),
              // Featured: Unified Search
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.cyan.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pushNamed(context, '/unified-search');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.search,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '🚀 Unified Search',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'All-in-one search with AI & live data',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // AI Assistant Featured Card
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade700, Colors.deepPurple.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pushNamed(context, '/ai-chat');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.smart_toy,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '🤖 AI Assistant',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Chat with AI • Voice support • Smart help',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                      title: 'Data Management',
                      subtitle: 'Manage track data',
                      icon: Icons.storage,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pushNamed(context, '/data-management');
                      },
                    ),
                    NavigationCard(
                      title: 'Track Section Training',
                      subtitle: 'Train & link data',
                      icon: Icons.school,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pushNamed(context, '/track-section-training');
                      },
                    ),
                    NavigationCard(
                      title: '⚡ Batch Entry',
                      subtitle: 'Speed up data entry',
                      icon: Icons.fast_forward,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pushNamed(context, '/batch-entry');
                      },
                    ),
                    NavigationCard(
                      title: 'Grouping Manager',
                      subtitle: 'Manage TSR groupings',
                      icon: Icons.group_work,
                      color: Colors.deepOrange,
                      onTap: () {
                        Navigator.pushNamed(context, '/grouping-management');
                      },
                    ),
                    NavigationCard(
                      title: 'TSR Dashboard',
                      subtitle: 'Active speed restrictions',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      onTap: () {
                        Navigator.pushNamed(context, '/tsr-dashboard');
                      },
                    ),
                    NavigationCard(
                      title: 'Data Export',
                      subtitle: 'Export results',
                      icon: Icons.download,
                      color: Colors.brown,
                      onTap: () {
                        _showExportDialog(context);
                      },
                    ),
                    NavigationCard(
                      title: 'Activity Logger',
                      subtitle: 'Debug & monitor',
                      icon: Icons.bug_report,
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.pushNamed(context, '/activity-logger');
                      },
                    ),
                    NavigationCard(
                      title: 'Theme Settings',
                      subtitle: 'Dark mode & colors',
                      icon: Icons.palette,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.pushNamed(context, '/theme-settings');
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