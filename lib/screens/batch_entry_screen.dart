// screens/batch_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/batch_models.dart';
import '../models/track_data.dart';
import '../services/batch_operation_service.dart';
import '../services/unified_data_service.dart';

/// Screen for batch entry of track sections
class BatchEntryScreen extends StatefulWidget {
  const BatchEntryScreen({super.key});

  @override
  State<BatchEntryScreen> createState() => _BatchEntryScreenState();
}

class _BatchEntryScreenState extends State<BatchEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchService = BatchOperationService();
  final _dataService = UnifiedDataService();

  // Controllers
  final _startTrackSectionController = TextEditingController();
  final _endTrackSectionController = TextEditingController();
  final _startChainageController = TextEditingController();
  final _endChainageController = TextEditingController();
  final _lcsCodeController = TextEditingController();
  final _stationController = TextEditingController();
  final _vccController = TextEditingController();

  // Selected values
  String? _selectedLine;
  String? _selectedRoadDirection;

  // State
  bool _isProcessing = false;
  bool _showPreview = false;
  List<Map<String, dynamic>> _previewSections = [];
  Map<int, ConflictInfo> _conflicts = {};
  Map<String, dynamic>? _previewStats;

  // Lines
  final List<String> _lines = [
    'District Line',
    'Circle Line',
    'Metropolitan Line',
    'Hammersmith & City Line',
    'Central Line',
    'Bakerloo Line',
    'Northern Line',
    'Piccadilly Line',
    'Victoria Line',
    'Jubilee Line',
    'Elizabeth Line',
  ];

  // Road directions
  final List<String> _roadDirections = ['EB', 'WB', 'NB', 'SB'];

  @override
  void dispose() {
    _startTrackSectionController.dispose();
    _endTrackSectionController.dispose();
    _startChainageController.dispose();
    _endChainageController.dispose();
    _lcsCodeController.dispose();
    _stationController.dispose();
    _vccController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Track Section Entry'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildInputSection(),
              const SizedBox(height: 20),
              _buildPreviewButton(),
              if (_showPreview) ...[
                const SizedBox(height: 20),
                _buildPreviewStats(),
                const SizedBox(height: 20),
                _buildPreviewList(),
                if (_conflicts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildConflictsSection(),
                ],
                const SizedBox(height: 20),
                _buildExecuteButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Batch Track Section Entry',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Speed up data population by creating multiple track sections at once. '
              'Enter start and end points, and the app will automatically interpolate '
              'all track sections in between with equally spaced chainage values.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Section Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startTrackSectionController,
                    decoration: const InputDecoration(
                      labelText: 'Start Track Section',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 10501',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endTrackSectionController,
                    decoration: const InputDecoration(
                      labelText: 'End Track Section',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 10520',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Chainage Range (meters)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startChainageController,
                    decoration: const InputDecoration(
                      labelText: 'Start Chainage',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 24567.8',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endChainageController,
                    decoration: const InputDecoration(
                      labelText: 'End Chainage',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 26789.4',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Shared Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lcsCodeController,
              decoration: const InputDecoration(
                labelText: 'LCS Code',
                border: OutlineInputBorder(),
                hintText: 'e.g., D011',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLine,
              decoration: const InputDecoration(
                labelText: 'Operating Line',
                border: OutlineInputBorder(),
              ),
              items: _lines.map((line) {
                return DropdownMenuItem(value: line, child: Text(line));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLine = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRoadDirection,
              decoration: const InputDecoration(
                labelText: 'Road Direction',
                border: OutlineInputBorder(),
              ),
              items: _roadDirections.map((dir) {
                return DropdownMenuItem(value: dir, child: Text(dir));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRoadDirection = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stationController,
              decoration: const InputDecoration(
                labelText: 'Station (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Upminster',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vccController,
              decoration: const InputDecoration(
                labelText: 'VCC (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., 4',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _generatePreview,
        icon: const Icon(Icons.preview),
        label: const Text('Generate Preview'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPreviewStats() {
    if (_previewStats == null) return const SizedBox.shrink();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Sections', '${_previewStats!['totalSections']}'),
            _buildStatRow('Total Distance', '${_previewStats!['totalDistance'].toStringAsFixed(1)} m'),
            _buildStatRow('Average Spacing', '${_previewStats!['averageSpacing'].toStringAsFixed(1)} m'),
            _buildStatRow('Direction', _previewStats!['direction']),
            if (_conflicts.isNotEmpty)
              _buildStatRow('Conflicts Found', '${_conflicts.length}', isWarning: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isWarning ? Colors.orange.shade700 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orange.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Preview (First 10 of ${_previewSections.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _previewSections.length > 10 ? 10 : _previewSections.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final section = _previewSections[index];
              final tsNumber = section['track_section_number'] as int;
              final chainage = section['thales_chainage'] as double;
              final meterage = section['lcs_meterage'] as double;
              final hasConflict = _conflicts.containsKey(tsNumber);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: hasConflict ? Colors.orange : Colors.blue,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text('TS $tsNumber'),
                subtitle: Text(
                  'Chainage: ${chainage.toStringAsFixed(1)}m | Meterage: ${meterage.toStringAsFixed(1)}m',
                ),
                trailing: hasConflict
                    ? const Icon(Icons.warning, color: Colors.orange)
                    : const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConflictsSection() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Conflicts Detected (${_conflicts.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'The following track sections already exist. Choose how to handle conflicts below.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...(_conflicts.entries.take(5).map((entry) {
              final conflict = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'TS ${conflict.trackSectionNumber}: Existing ${conflict.existingChainage.toStringAsFixed(1)}m vs Proposed ${conflict.proposedChainage.toStringAsFixed(1)}m',
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              );
            })),
            if (_conflicts.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '... and ${_conflicts.length - 5} more conflicts',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecuteButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_conflicts.isEmpty)
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _executeBatch('skip_conflicts'),
            icon: const Icon(Icons.check_circle),
            label: const Text('Execute Batch (No Conflicts)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        if (_conflicts.isNotEmpty) ...[
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _executeBatch('skip_conflicts'),
            icon: const Icon(Icons.skip_next),
            label: Text('Skip Conflicts (Insert ${_previewSections.length - _conflicts.length} sections)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    _showConflictDialog();
                  },
            icon: const Icon(Icons.cancel),
            label: const Text('Stop - Adjust Parameters'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade700),
            ),
          ),
        ],
      ],
    );
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflicts Found'),
        content: Text(
          'Found ${_conflicts.length} conflicting track sections. '
          'Please adjust your parameters and try again to avoid conflicts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePreview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final startTS = int.parse(_startTrackSectionController.text);
      final endTS = int.parse(_endTrackSectionController.text);
      final startChainage = double.parse(_startChainageController.text);
      final endChainage = double.parse(_endChainageController.text);

      // Validate
      if (!_batchService.validateBatchParameters(
        startTrackSection: startTS,
        endTrackSection: endTS,
        startChainage: startChainage,
        endChainage: endChainage,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid parameters')),
        );
        return;
      }

      // Generate preview
      final sections = _batchService.generateTrackSections(
        startTrackSection: startTS,
        endTrackSection: endTS,
        startChainage: startChainage,
        endChainage: endChainage,
        lcsCode: _lcsCodeController.text,
        operatingLine: _selectedLine!,
        roadDirection: _selectedRoadDirection!,
        station: _stationController.text.isNotEmpty ? _stationController.text : null,
        vcc: _vccController.text.isNotEmpty ? _vccController.text : null,
      );

      // Calculate stats
      final stats = _batchService.calculatePreviewStats(
        startTrackSection: startTS,
        endTrackSection: endTS,
        startChainage: startChainage,
        endChainage: endChainage,
      );

      // Check conflicts
      final existingTrackSections = _dataService.getAllTrackSections();
      final conflicts = await _batchService.checkConflicts(
        generatedSections: sections,
        operatingLine: _selectedLine!,
        roadDirection: _selectedRoadDirection!,
        existingTrackSections: existingTrackSections,
      );

      setState(() {
        _previewSections = sections;
        _previewStats = stats;
        _conflicts = conflicts;
        _showPreview = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preview generated: ${sections.length} sections${conflicts.isNotEmpty ? ", ${conflicts.length} conflicts" : ""}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _executeBatch(String conflictResolution) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final startTS = int.parse(_startTrackSectionController.text);
      final endTS = int.parse(_endTrackSectionController.text);
      final startChainage = double.parse(_startChainageController.text);
      final endChainage = double.parse(_endChainageController.text);

      final existingTrackSections = _dataService.getAllTrackSections();

      final batchId = await _batchService.executeBatchOperation(
        startTrackSection: startTS,
        endTrackSection: endTS,
        startChainage: startChainage,
        endChainage: endChainage,
        lcsCode: _lcsCodeController.text,
        operatingLine: _selectedLine!,
        roadDirection: _selectedRoadDirection!,
        station: _stationController.text.isNotEmpty ? _stationController.text : null,
        vcc: _vccController.text.isNotEmpty ? _vccController.text : null,
        existingTrackSections: existingTrackSections,
        conflictResolution: conflictResolution,
      );

      if (batchId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch operation completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _formKey.currentState!.reset();
        setState(() {
          _showPreview = false;
          _previewSections = [];
          _conflicts = {};
          _previewStats = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch operation failed or stopped due to conflicts'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
