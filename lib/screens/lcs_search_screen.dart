// screens/lcs_search_screen.dart
import 'package:flutter/material.dart';
import 'package:track_sections_manager/models/track_data.dart';
import 'package:track_sections_manager/services/data_service.dart';
import 'package:track_sections_manager/widgets/result_card.dart';

class LCSSearchScreen extends StatefulWidget {
  const LCSSearchScreen({super.key});

  @override
  _LCSSearchScreenState createState() => _LCSSearchScreenState();
}

class _LCSSearchScreenState extends State<LCSSearchScreen> {
  final TextEditingController _lcsController = TextEditingController();
  QueryResult? _result;
  bool _isLoading = false;
  List<String> _recentSearches = [];

  void _searchLcsCode() {
    final lcsCode = _lcsController.text.trim();

    if (lcsCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an LCS Code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recentSearches.insert(0, lcsCode);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
    });

    // Simulate API call
    Future.delayed(const Duration(milliseconds: 500), () {
      final result = DataService().searchByLcsCode(lcsCode);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LCS Code Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Enter LCS Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _lcsController,
                      decoration: InputDecoration(
                        labelText: 'LCS Code',
                        hintText: 'e.g., M189-M-RD21',
                        prefixIcon: const Icon(Icons.qr_code),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchLcsCode,
                      icon: const Icon(Icons.search),
                      label: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Search LCS Code'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _recentSearches.map((search) {
                          return Chip(
                            label: Text(search),
                            onDeleted: () {
                              setState(() {
                                _recentSearches.remove(search);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            if (_result != null) ...[
              const Text(
                'Search Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ResultCard(result: _result!),
              if (_result!.nearestSection == null) ...[
                const SizedBox(height: 20),
                const Card(
                  color: Colors.orangeAccent,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No track section found for this LCS code. Try a different code.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}