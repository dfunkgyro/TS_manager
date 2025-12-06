// widgets/network_map.dart
import 'package:flutter/material.dart';

class NetworkMap extends StatelessWidget {
  final Map<String, dynamic> connections;

  const NetworkMap({super.key, required this.connections});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Connections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // This would be replaced with an actual map or diagram
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.map,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Connection list
            if (connections['connections'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected Lines:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (connections['connections'] as Map<String, dynamic>)
                        .keys
                        .map((line) => Chip(
                              label: Text(line),
                              backgroundColor: _getLineColor(line),
                            ))
                        .toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getLineColor(String line) {
    const lineColors = {
      'District Line': Color.fromRGBO(200, 230, 201, 1),
      'Circle Line': Color.fromRGBO(255, 249, 196, 1),
      'Metropolitan Line': Color.fromRGBO(225, 190, 231, 1),
      'Hammersmith & City Line': Color.fromRGBO(248, 187, 208, 1),
    };
    return lineColors[line] ?? Colors.blue.shade100;
  }
}