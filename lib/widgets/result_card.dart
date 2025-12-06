// widgets/result_card.dart
import 'package:flutter/material.dart';
import '../models/track_data.dart';

class ResultCard extends StatelessWidget {
  final QueryResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.inputLcsCode != null)
              _buildInfoRow('Input LCS Code', result.inputLcsCode!),
            if (result.inputMeterage > 0)
              _buildInfoRow('Input Meterage', '${result.inputMeterage.toStringAsFixed(2)} m'),
            if (result.nearestLocation != null) ...[
              const Divider(),
              _buildInfoRow('Nearest Location', result.nearestLocation!.name),
              _buildInfoRow('Location Code', result.nearestLocation!.code),
              _buildInfoRow('Reference Meterage', '${result.nearestLocation!.referenceMeterage.toStringAsFixed(2)} m'),
              _buildInfoRow('Distance to Location', '${result.distanceToNearestLocation.toStringAsFixed(2)} m'),
            ],
            if (result.nearestSection != null) ...[
              const Divider(),
              _buildInfoRow('Track Section', result.nearestSection!.trackSection),
              _buildInfoRow('Track', result.nearestSection!.track),
              _buildInfoRow('Section Meterage', '${result.nearestSection!.lcsMeterageStart.toStringAsFixed(2)} - ${result.nearestSection!.lcsMeterageEnd.toStringAsFixed(2)} m'),
              _buildInfoRow('Segment ID', result.nearestSection!.segmentId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}