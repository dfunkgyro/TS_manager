// screens/tsr_creation_wizard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tsr_models.dart';
import '../models/grouping_models.dart';
import '../services/supabase_service.dart';
import '../services/unified_data_service.dart';

/// Multi-step wizard for creating TSRs
class TSRCreationWizardScreen extends StatefulWidget {
  const TSRCreationWizardScreen({super.key});

  @override
  State<TSRCreationWizardScreen> createState() => _TSRCreationWizardScreenState();
}

class _TSRCreationWizardScreenState extends State<TSRCreationWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = SupabaseService();
  final _dataService = UnifiedDataService();

  // Wizard state
  int _currentStep = 0;
  bool _isLoading = false;

  // TSR data
  final _tsrNumberController = TextEditingController();
  final _tsrNameController = TextEditingController();
  final _lcsCodeController = TextEditingController();
  final _startMeterageController = TextEditingController();
  final _endMeterageController = TextEditingController();
  final _normalSpeedController = TextEditingController();
  final _restrictedSpeedController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requestedByController = TextEditingController();
  final _approvedByController = TextEditingController();
  final _contactInfoController = TextEditingController();

  String? _selectedLine;
  String? _selectedRoadDirection;
  String _selectedReason = TSRReason.construction;
  DateTime? _effectiveFrom;
  DateTime? _effectiveUntil;

  List<int> _affectedTrackSections = [];
  List<TrackSectionGrouping> _foundGroupings = [];
  List<Map<String, dynamic>> _conflicts = [];

  @override
  void dispose() {
    _tsrNumberController.dispose();
    _tsrNameController.dispose();
    _lcsCodeController.dispose();
    _startMeterageController.dispose();
    _endMeterageController.dispose();
    _normalSpeedController.dispose();
    _restrictedSpeedController.dispose();
    _descriptionController.dispose();
    _requestedByController.dispose();
    _approvedByController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create TSR'),
        backgroundColor: Colors.red.shade700,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.red.shade700,
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: (step) => setState(() => _currentStep = step),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  if (_currentStep < 4)
                    ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_currentStep == 4 ? 'Create TSR' : 'Continue'),
                    ),
                  if (_currentStep == 4)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createTSR,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Create TSR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _isLoading ? null : details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Information'),
              content: _buildBasicInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Location & Range'),
              content: _buildLocationStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Speed & Dates'),
              content: _buildSpeedDatesStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Affected Track Sections'),
              content: _buildAffectedSectionsStep(),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Review & Confirm'),
              content: _buildReviewStep(),
              isActive: _currentStep >= 4,
              state: StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _tsrNumberController,
            decoration: const InputDecoration(
              labelText: 'TSR Number *',
              hintText: 'e.g., TSR-2024-001',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tsrNameController,
            decoration: const InputDecoration(
              labelText: 'TSR Name (Optional)',
              hintText: 'e.g., Upminster Track Work',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              border: OutlineInputBorder(),
            ),
            items: TSRReason.all.map((reason) {
              return DropdownMenuItem(
                value: reason,
                child: Text(TSRReason.getDisplayName(reason)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Detailed description of the restriction',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _lcsCodeController,
          decoration: const InputDecoration(
            labelText: 'LCS Code *',
            hintText: 'e.g., D011',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startMeterageController,
                decoration: const InputDecoration(
                  labelText: 'Start Meterage (m) *',
                  hintText: 'e.g., 0',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _endMeterageController,
                decoration: const InputDecoration(
                  labelText: 'End Meterage (m) *',
                  hintText: 'e.g., 500',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  final start = double.tryParse(_startMeterageController.text);
                  final end = double.tryParse(value);
                  if (start != null && end != null && end <= start) {
                    return 'Must be > start';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedLine,
          decoration: const InputDecoration(
            labelText: 'Operating Line *',
            border: OutlineInputBorder(),
          ),
          items: [
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
          ].map((line) {
            return DropdownMenuItem(value: line, child: Text(line));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLine = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedRoadDirection,
          decoration: const InputDecoration(
            labelText: 'Road Direction (Optional)',
            border: OutlineInputBorder(),
          ),
          items: ['EB', 'WB', 'NB', 'SB'].map((dir) {
            return DropdownMenuItem(value: dir, child: Text(dir));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedRoadDirection = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSpeedDatesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _normalSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Normal Speed (mph)',
                  hintText: 'e.g., 60',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _restrictedSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Restricted Speed (mph) *',
                  hintText: 'e.g., 20',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Effective From *'),
          subtitle: Text(
            _effectiveFrom != null
                ? DateFormat('MMM dd, yyyy HH:mm').format(_effectiveFrom!)
                : 'Not set',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _selectDateTime(true),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Effective Until (Optional)'),
          subtitle: Text(
            _effectiveUntil != null
                ? DateFormat('MMM dd, yyyy HH:mm').format(_effectiveUntil!)
                : 'Indefinite',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _selectDateTime(false),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _requestedByController,
          decoration: const InputDecoration(
            labelText: 'Requested By',
            hintText: 'Name of requester',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _approvedByController,
          decoration: const InputDecoration(
            labelText: 'Approved By',
            hintText: 'Name of approver',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactInfoController,
          decoration: const InputDecoration(
            labelText: 'Contact Information',
            hintText: 'Phone or email',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildAffectedSectionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
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
                      'Auto-Detected Track Sections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on your LCS code and meterage range, we found the following track sections:',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_affectedTrackSections.isEmpty)
          ElevatedButton.icon(
            onPressed: _findAffectedTrackSections,
            icon: const Icon(Icons.search),
            label: const Text('Find Track Sections'),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_affectedTrackSections.length} Track Sections Found',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _affectedTrackSections.map((tsNumber) {
                  return Chip(
                    label: Text('TS $tsNumber'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _affectedTrackSections.remove(tsNumber);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _addTrackSectionManually(),
                icon: const Icon(Icons.add),
                label: const Text('Add Track Section Manually'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _findAffectedTrackSections,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        if (_conflicts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
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
                        'Conflicts Detected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This TSR overlaps with existing TSRs on some track sections:',
                  ),
                  const SizedBox(height: 8),
                  ...(_conflicts.take(3).map((conflict) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• ${conflict['message']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  })),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review TSR Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildReviewItem('TSR Number', _tsrNumberController.text),
        if (_tsrNameController.text.isNotEmpty)
          _buildReviewItem('TSR Name', _tsrNameController.text),
        _buildReviewItem('Reason', TSRReason.getDisplayName(_selectedReason)),
        _buildReviewItem('LCS Code', _lcsCodeController.text),
        _buildReviewItem(
          'Meterage Range',
          '${_startMeterageController.text}m - ${_endMeterageController.text}m',
        ),
        _buildReviewItem('Operating Line', _selectedLine ?? 'Not set'),
        if (_selectedRoadDirection != null)
          _buildReviewItem('Road Direction', _selectedRoadDirection!),
        _buildReviewItem(
          'Restricted Speed',
          '${_restrictedSpeedController.text} mph',
        ),
        if (_normalSpeedController.text.isNotEmpty)
          _buildReviewItem('Normal Speed', '${_normalSpeedController.text} mph'),
        _buildReviewItem(
          'Effective From',
          _effectiveFrom != null
              ? DateFormat('MMM dd, yyyy HH:mm').format(_effectiveFrom!)
              : 'Not set',
        ),
        _buildReviewItem(
          'Effective Until',
          _effectiveUntil != null
              ? DateFormat('MMM dd, yyyy HH:mm').format(_effectiveUntil!)
              : 'Indefinite',
        ),
        _buildReviewItem(
          'Affected Track Sections',
          '${_affectedTrackSections.length} sections',
        ),
        const SizedBox(height: 16),
        if (_conflicts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_conflicts.length} conflict(s) detected. Review conflicts before creating TSR.',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime(bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isStartDate) {
            _effectiveFrom = dateTime;
          } else {
            _effectiveUntil = dateTime;
          }
        });
      }
    }
  }

  Future<void> _findAffectedTrackSections() async {
    if (_lcsCodeController.text.isEmpty ||
        _startMeterageController.text.isEmpty ||
        _endMeterageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in LCS code and meterage range')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startMeterage = double.parse(_startMeterageController.text);
      final endMeterage = double.parse(_endMeterageController.text);

      // Search for groupings in this range
      if (_supabase.isInitialized) {
        final groupings = await _supabase.getGroupingsByLCS(_lcsCodeController.text);

        final relevantGroupings = groupings.where((g) {
          final gData = TrackSectionGrouping.fromJson(g);
          final meterage = gData.meterageFromLcs;
          return meterage >= startMeterage && meterage <= endMeterage;
        }).toList();

        final trackSections = <int>{};
        for (final grouping in relevantGroupings) {
          final g = TrackSectionGrouping.fromJson(grouping);
          trackSections.addAll(g.trackSectionNumbers);
        }

        setState(() {
          _affectedTrackSections = trackSections.toList()..sort();
          _foundGroupings = relevantGroupings.map((g) => TrackSectionGrouping.fromJson(g)).toList();
        });

        // Check for conflicts
        await _checkConflicts();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding track sections: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkConflicts() async {
    if (!_supabase.isInitialized) return;

    try {
      final activeTSRs = await _supabase.getActiveTSRs(
        operatingLine: _selectedLine,
      );

      final conflicts = <Map<String, dynamic>>[];

      for (final tsrData in activeTSRs) {
        final tsr = TemporarySpeedRestriction.fromJson(tsrData);

        // Check if this TSR overlaps with our range
        if (tsr.lcsCode == _lcsCodeController.text) {
          final ourStart = double.parse(_startMeterageController.text);
          final ourEnd = double.parse(_endMeterageController.text);

          final overlaps = !(tsr.endMeterage < ourStart || tsr.startMeterage > ourEnd);

          if (overlaps) {
            conflicts.add({
              'tsr': tsr,
              'message': 'Overlaps with TSR ${tsr.tsrNumber} (${tsr.startMeterage}m - ${tsr.endMeterage}m)',
            });
          }
        }
      }

      setState(() {
        _conflicts = conflicts;
      });
    } catch (e) {
      debugPrint('Error checking conflicts: $e');
    }
  }

  Future<void> _addTrackSectionManually() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Track Section'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Track Section Number',
            hintText: 'e.g., 10501',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final tsNumber = int.tryParse(result);
      if (tsNumber != null && !_affectedTrackSections.contains(tsNumber)) {
        setState(() {
          _affectedTrackSections.add(tsNumber);
          _affectedTrackSections.sort();
        });
      }
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (_lcsCodeController.text.isEmpty ||
          _startMeterageController.text.isEmpty ||
          _endMeterageController.text.isEmpty ||
          _selectedLine == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (_restrictedSpeedController.text.isEmpty || _effectiveFrom == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in speed and start date')),
        );
        return;
      }
    } else if (_currentStep == 3 && _affectedTrackSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one track section')),
      );
      return;
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  Future<void> _createTSR() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tsr = await _supabase.createTSR(
        tsrNumber: _tsrNumberController.text,
        tsrName: _tsrNameController.text.isNotEmpty ? _tsrNameController.text : null,
        lcsCode: _lcsCodeController.text,
        startMeterage: double.parse(_startMeterageController.text),
        endMeterage: double.parse(_endMeterageController.text),
        operatingLine: _selectedLine!,
        roadDirection: _selectedRoadDirection,
        restrictedSpeedMph: int.parse(_restrictedSpeedController.text),
        normalSpeedMph: _normalSpeedController.text.isNotEmpty
            ? int.parse(_normalSpeedController.text)
            : null,
        effectiveFrom: _effectiveFrom!,
        effectiveUntil: _effectiveUntil,
        reason: _selectedReason,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        requestedBy: _requestedByController.text.isNotEmpty
            ? _requestedByController.text
            : null,
        approvedBy: _approvedByController.text.isNotEmpty
            ? _approvedByController.text
            : null,
        affectedTrackSections: _affectedTrackSections,
      );

      if (tsr != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TSR created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to create TSR');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating TSR: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
