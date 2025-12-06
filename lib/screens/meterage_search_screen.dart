// screens/meterage_search_screen.dart
import 'package:flutter/material.dart';
import 'package:track_sections_app/models/track_data.dart';
import 'package:track_sections_app/services/data_service.dart';
import 'package:track_sections_app/widgets/result_card.dart';

class MeterageSearchScreen extends StatefulWidget {
  const MeterageSearchScreen({super.key});

  @override
  _MeterageSearchScreenState createState() => _MeterageSearchScreenState();
}

class _MeterageSearchScreenState extends State<MeterageSearchScreen> {
  final TextEditingController _meterageController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(text: '50');
  QueryResult? _result;
  bool _isLoading = false;

  void _searchMeterage() {
    final meterage = double.tryParse(_meterageController.text);
    final radius = double.tryParse(_radiusController.text) ?? 50;

    if (meterage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid meterage value'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(const Duration(milliseconds: 500), () {
      final result = DataService().searchByMeterage(meterage, radius: radius);
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
        title: const Text('Meterage Search'),
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
                      'Enter Meterage Value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _meterageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Meterage',
                        hintText: 'e.g., 15000.5',
                        prefixIcon: const Icon(Icons.speed),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Search Radius (meters)',
                        hintText: 'e.g., 50',
                        prefixIcon: const Icon(Icons.radar),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchMeterage,
                      icon: const Icon(Icons.search),
                      label: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Search Meterage'),
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
              const SizedBox(height: 20),
              if (_result!.nearestSection != null) ...[
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detailed Section Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoRow('LCS Code', _result!.nearestSection!.lcsCode),
                        _buildInfoRow('Track Section', _result!.nearestSection!.trackSection),
                        _buildInfoRow('Track', _result!.nearestSection!.track),
                        _buildInfoRow('Operating Line', _result!.nearestSection!.operatingLine),
                        _buildInfoRow('Start Meterage', _result!.nearestSection!.lcsMeterageStart.toString()),
                        _buildInfoRow('End Meterage', _result!.nearestSection!.lcsMeterageEnd.toString()),
                        _buildInfoRow('Segment ID', _result!.nearestSection!.segmentId),
                        if (_result!.nearestSection!.physicalAssets.isNotEmpty)
                          _buildInfoRow('Physical Assets', _result!.nearestSection!.physicalAssets),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Share functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Results copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share Results'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Export functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Results exported'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}