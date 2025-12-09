// screens/grouping_management_screen.dart
import 'package:flutter/material.dart';
import '../models/grouping_models.dart';
import '../services/supabase_service.dart';
import '../services/unified_data_service.dart';

/// Screen for managing track section groupings
class GroupingManagementScreen extends StatefulWidget {
  const GroupingManagementScreen({super.key});

  @override
  State<GroupingManagementScreen> createState() => _GroupingManagementScreenState();
}

class _GroupingManagementScreenState extends State<GroupingManagementScreen> {
  final _supabase = SupabaseService();
  final _dataService = UnifiedDataService();

  List<TrackSectionGrouping> _groupings = [];
  bool _isLoading = false;
  String? _selectedLine;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroupings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load from Supabase if available
      if (_supabase.isInitialized) {
        final groupingsData = await _supabase.client
            .from('track_section_groupings')
            .select()
            .order('operating_line')
            .order('lcs_code')
            .order('meterage_from_lcs');

        final groupings = (groupingsData as List)
            .map((data) => TrackSectionGrouping.fromJson(data))
            .toList();

        setState(() {
          _groupings = groupings;
        });
      } else {
        // Build groupings from local data
        _buildLocalGroupings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading groupings: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildLocalGroupings() {
    // TODO: Build groupings from local track sections
    // This would analyze all track sections and create groupings
    // based on LCS code and meterage proximity
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Section Groupings'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupings,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateGroupingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupings.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search LCS Code or Station...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                // Trigger rebuild to filter groupings
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedLine,
            decoration: InputDecoration(
              labelText: 'Filter by Line',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Lines')),
              ...['District Line', 'Circle Line', 'Metropolitan Line', 'Hammersmith & City Line']
                  .map((line) => DropdownMenuItem(value: line, child: Text(line))),
            ],
            onChanged: (value) {
              setState(() {
                _selectedLine = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Groupings Found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Groupings are created when track sections\nshare the same LCS code and meterage',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateGroupingDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Grouping'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupingsList() {
    final filteredGroupings = _groupings.where((grouping) {
      final searchLower = _searchController.text.toLowerCase();
      final matchesSearch = searchLower.isEmpty ||
          grouping.lcsCode.toLowerCase().contains(searchLower) ||
          (grouping.station?.toLowerCase().contains(searchLower) ?? false);

      final matchesLine =
          _selectedLine == null || grouping.operatingLine == _selectedLine;

      return matchesSearch && matchesLine;
    }).toList();

    return ListView.builder(
      itemCount: filteredGroupings.length,
      itemBuilder: (context, index) {
        final grouping = filteredGroupings[index];
        return _buildGroupingCard(grouping);
      },
    );
  }

  Widget _buildGroupingCard(TrackSectionGrouping grouping) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: grouping.verified ? Colors.green : Colors.orange,
          child: Text(
            '${grouping.trackSectionCount}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          grouping.displayLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${grouping.operatingLine} ${grouping.roadDirection ?? ""}'),
            if (grouping.station != null) Text('Station: ${grouping.station}'),
            Text(
              grouping.trackSectionsDisplay,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!grouping.verified)
              Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          _buildGroupingDetails(grouping),
        ],
      ),
    );
  }

  Widget _buildGroupingDetails(TrackSectionGrouping grouping) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Track Sections:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${grouping.trackSectionCount} sections',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: grouping.trackSectionNumbers.map((tsNumber) {
              return Chip(
                label: Text('TS $tsNumber'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTrackSectionFromGrouping(grouping, tsNumber),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addTrackSectionToGrouping(grouping),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Track Section'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: grouping.verified
                      ? null
                      : () => _verifyGrouping(grouping),
                  icon: const Icon(Icons.check),
                  label: Text(grouping.verified ? 'Verified' : 'Verify'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: grouping.verified ? Colors.green : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _deleteGrouping(grouping),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Grouping'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ),
          if (grouping.description != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Description:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(grouping.description!),
          ],
        ],
      ),
    );
  }

  void _showCreateGroupingDialog() {
    final lcsCodeController = TextEditingController();
    final meterageController = TextEditingController();
    final toleranceController = TextEditingController(text: '10');
    final stationController = TextEditingController();
    String? selectedLine;
    String? selectedRoadDirection;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Grouping'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lcsCodeController,
                  decoration: const InputDecoration(
                    labelText: 'LCS Code',
                    hintText: 'e.g., D011',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meterageController,
                  decoration: const InputDecoration(
                    labelText: 'Meterage from LCS',
                    hintText: 'e.g., 45.0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: toleranceController,
                  decoration: const InputDecoration(
                    labelText: 'Tolerance (meters)',
                    hintText: 'e.g., 10',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLine,
                  decoration: const InputDecoration(labelText: 'Operating Line'),
                  items: [
                    'District Line',
                    'Circle Line',
                    'Metropolitan Line',
                    'Hammersmith & City Line'
                  ].map((line) {
                    return DropdownMenuItem(value: line, child: Text(line));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLine = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRoadDirection,
                  decoration: const InputDecoration(labelText: 'Road Direction'),
                  items: ['EB', 'WB', 'NB', 'SB'].map((dir) {
                    return DropdownMenuItem(value: dir, child: Text(dir));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRoadDirection = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stationController,
                  decoration: const InputDecoration(
                    labelText: 'Station (Optional)',
                    hintText: 'e.g., Upminster',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (lcsCodeController.text.isEmpty ||
                    meterageController.text.isEmpty ||
                    selectedLine == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                  return;
                }

                final meterage = double.tryParse(meterageController.text);
                final tolerance = double.tryParse(toleranceController.text) ?? 10;

                if (meterage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid meterage value')),
                  );
                  return;
                }

                Navigator.pop(context);

                if (_supabase.isInitialized) {
                  final grouping = await _supabase.getOrCreateGrouping(
                    lcsCode: lcsCodeController.text,
                    meterage: meterage,
                    operatingLine: selectedLine!,
                    roadDirection: selectedRoadDirection,
                    tolerance: tolerance,
                  );

                  if (grouping != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grouping created successfully')),
                    );
                    _loadGroupings();
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTrackSectionToGrouping(TrackSectionGrouping grouping) async {
    final tsController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Track Section'),
        content: TextField(
          controller: tsController,
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
            onPressed: () => Navigator.pop(context, tsController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final tsNumber = int.tryParse(result);
      if (tsNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid track section number')),
        );
        return;
      }

      if (_supabase.isInitialized && grouping.id != null) {
        final success = await _supabase.addTrackSectionToGrouping(
          grouping.id!,
          tsNumber,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Track section added')),
          );
          _loadGroupings();
        }
      } else {
        // Update local grouping
        setState(() {
          final index = _groupings.indexOf(grouping);
          if (index != -1) {
            _groupings[index] = grouping.addTrackSection(tsNumber);
          }
        });
      }
    }
  }

  Future<void> _removeTrackSectionFromGrouping(
    TrackSectionGrouping grouping,
    int tsNumber,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Track Section'),
        content: Text('Remove TS $tsNumber from this grouping?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_supabase.isInitialized && grouping.id != null) {
        final success = await _supabase.removeTrackSectionFromGrouping(
          grouping.id!,
          tsNumber,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Track section removed')),
          );
          _loadGroupings();
        }
      } else {
        setState(() {
          final index = _groupings.indexOf(grouping);
          if (index != -1) {
            _groupings[index] = grouping.removeTrackSection(tsNumber);
          }
        });
      }
    }
  }

  Future<void> _verifyGrouping(TrackSectionGrouping grouping) async {
    if (_supabase.isInitialized && grouping.id != null) {
      final success = await _supabase.updateGroupingTrackSections(
        grouping.id!,
        grouping.trackSectionNumbers,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grouping verified')),
        );
        _loadGroupings();
      }
    } else {
      setState(() {
        final index = _groupings.indexOf(grouping);
        if (index != -1) {
          _groupings[index] = grouping.markAsVerified();
        }
      });
    }
  }

  Future<void> _deleteGrouping(TrackSectionGrouping grouping) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Grouping'),
        content: const Text('Are you sure you want to delete this grouping?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_supabase.isInitialized && grouping.id != null) {
        final success = await _supabase.deleteGrouping(grouping.id!);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grouping deleted')),
          );
          _loadGroupings();
        }
      } else {
        setState(() {
          _groupings.remove(grouping);
        });
      }
    }
  }
}
