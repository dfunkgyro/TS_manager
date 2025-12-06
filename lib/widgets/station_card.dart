// widgets/station_card.dart
import 'package:flutter/material.dart';
import '../models/enhanced_track_data.dart';

class StationCard extends StatelessWidget {
  final LCSStationMapping mapping;

  const StationCard({super.key, required this.mapping});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: _getLineIcon(mapping.line),
        title: Text(
          mapping.station,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mapping.line),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    mapping.lcsCode,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getLineColor(mapping.line),
                ),
                if (mapping.aliases.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'aka ${mapping.aliases.first}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to station details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StationDetailsScreen(mapping: mapping),
            ),
          );
        },
      ),
    );
  }

  Widget _getLineIcon(String line) {
    final color = _getLineColor(line);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.train,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Color _getLineColor(String line) {
    const lineColors = {
      'District Line': Colors.green,
      'Circle Line': Color.fromRGBO(251, 192, 45, 1),
      'Metropolitan Line': Colors.purple,
      'Hammersmith & City Line': Color.fromRGBO(240, 98, 146, 1),
    };
    return lineColors[line] ?? Colors.blue;
  }
}

class StationDetailsScreen extends StatelessWidget {
  final LCSStationMapping mapping;

  const StationDetailsScreen({super.key, required this.mapping});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mapping.station),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.train),
                      title: const Text('Station Name'),
                      subtitle: Text(mapping.station),
                    ),
                    ListTile(
                      leading: const Icon(Icons.line_style),
                      title: const Text('Line'),
                      subtitle: Text(mapping.line),
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: const Text('LCS Code'),
                      subtitle: Text(mapping.lcsCode),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connected Track Sections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildTrackSectionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackSectionsList() {
    // This would fetch actual sections from the service
    return ListView.builder(
      itemCount: 3, // Example count
      itemBuilder: (context, index) => Card(
        child: ListTile(
          title: Text('Track Section ${index + 1}'),
          subtitle: const Text('Meterage: 15000 - 15100'),
          trailing: const Chip(label: Text('Active')),
        ),
      ),
    );
  }
}