import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_track_data.dart' show LCSStationMapping;
import 'package:track_sections_manager/services/unified_data_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Track Section Training Screen - Core feature for app learning
/// Users can view, edit, and link track sections to locations, LCS codes, and chainages
class TrackSectionTrainingScreen extends StatefulWidget {
  const TrackSectionTrainingScreen({super.key});

  @override
  State<TrackSectionTrainingScreen> createState() => _TrackSectionTrainingScreenState();
}

class _TrackSectionTrainingScreenState extends State<TrackSectionTrainingScreen> {
  final UnifiedDataService _dataService = UnifiedDataService();

  bool _isLoading = true;
  List<EnhancedTrackSection> _allTrackSections = [];
  List<EnhancedTrackSection> _filteredTrackSections = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _meterageController = TextEditingController();
  String? _selectedLine;
  String? _searchMode = 'trackSection'; // 'trackSection', 'location', 'chainage'

  // Edit mode
  EnhancedTrackSection? _editingSection;
  final TextEditingController _lcsCodeController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final TextEditingController _chainageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedEditLine;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_performSearch);
    _meterageController.addListener(_performSearch);
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _dataService.loadAllData();
      _allTrackSections = _dataService.allTrackSections;
      _filteredTrackSections = List.from(_allTrackSections);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    final meterageText = _meterageController.text.trim();

    if (query.isEmpty && _selectedLine == null) {
      setState(() {
        _filteredTrackSections = List.from(_allTrackSections);
      });
      return;
    }

    setState(() {
      _filteredTrackSections = _allTrackSections.where((ts) {
        // Line filter
        if (_selectedLine != null && ts.operatingLine != _selectedLine) {
          return false;
        }

        if (query.isEmpty) return true;

        switch (_searchMode) {
          case 'trackSection':
            // Search by track section number (must be 5 digits)
            final tsNumber = ts.trackSection.toString();
            if (tsNumber.contains(query)) {
              // If meterage is provided, check chainage proximity
              if (meterageText.isNotEmpty) {
                final meterage = double.tryParse(meterageText);
                if (meterage != null) {
                  return _isWithinMeterageRange(ts, meterage);
                }
              }
              return true;
            }
            return false;

          case 'location':
            // Search by station/location name
            return ts.newShortDescription.toLowerCase().contains(query.toLowerCase()) ||
                   ts.currentLcsCode.toLowerCase().contains(query.toLowerCase());

          case 'chainage':
            // Search by chainage (exact or range)
            final chainage = double.tryParse(query);
            if (chainage != null) {
              return ts.thalesChainage >= (chainage - 100) &&
                     ts.thalesChainage <= (chainage + 100);
            }
            return false;

          default:
            return true;
        }
      }).toList();

      // Sort by track section ID
      _filteredTrackSections.sort((a, b) => a.trackSection.compareTo(b.trackSection));
    });
  }

  bool _isWithinMeterageRange(EnhancedTrackSection ts, double meterage) {
    // Check if track section is within specified meterage range (±50m default)
    final range = meterage;
    return (ts.lcsMeterageStart - range <= meterage && ts.lcsMeterageStart + range >= meterage) ||
           (ts.lcsMeterageEnd - range <= meterage && ts.lcsMeterageEnd + range >= meterage) ||
           (ts.thalesChainage - range * 1000 <= meterage * 1000 &&
            ts.thalesChainage + range * 1000 >= meterage * 1000);
  }

  Future<void> _editTrackSection(EnhancedTrackSection section) async {
    setState(() {
      _editingSection = section;
      _lcsCodeController.text = section.currentLcsCode;
      _stationController.text = section.newShortDescription;
      _chainageController.text = section.thalesChainage.toStringAsFixed(3);
      _descriptionController.text = section.newLongDescription;
      _selectedEditLine = section.operatingLine;
    });

    await showDialog(
      context: context,
      builder: (context) => _buildEditDialog(),
    );
  }

  Widget _buildEditDialog() {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          Text('Edit Track Section ${_editingSection?.trackSection}'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track Section ID: ${_editingSection?.trackSection}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _lcsCodeController,
                decoration: const InputDecoration(
                  labelText: 'LCS Code *',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(),
                  helperText: 'e.g., M187, BAK/A',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _stationController,
                decoration: const InputDecoration(
                  labelText: 'Station/Location Name *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedEditLine,
                decoration: const InputDecoration(
                  labelText: 'Line *',
                  prefixIcon: Icon(Icons.train),
                  border: OutlineInputBorder(),
                ),
                items: _dataService.allLines.map((line) => DropdownMenuItem(
                  value: line,
                  child: Text(line),
                )).toList(),
                onChanged: (value) => setState(() => _selectedEditLine = value),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _chainageController,
                decoration: const InputDecoration(
                  labelText: 'Chainage (m) *',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                  helperText: 'Absolute chainage position',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Current Values',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Operating Line Code: ${_editingSection?.operatingLineCode}'),
                    Text('VCC: ${_editingSection?.vcc.toStringAsFixed(0)}'),
                    Text('Segment ID: ${_editingSection?.segmentId}'),
                    Text('Track: ${_editingSection?.track}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => _saveTrackSection(),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveTrackSection() async {
    if (_editingSection == null) return;

    try {
      // Create updated track section
      final updatedSection = EnhancedTrackSection(
        id: _editingSection!.id,
        currentLcsCode: _lcsCodeController.text,
        legacyLcsCode: _editingSection!.legacyLcsCode,
        legacyJnpLcsCode: _editingSection!.legacyJnpLcsCode,
        roadStatus: _editingSection!.roadStatus,
        operatingLineCode: _editingSection!.operatingLineCode,
        operatingLine: _selectedEditLine ?? _editingSection!.operatingLine,
        newLongDescription: _descriptionController.text,
        newShortDescription: _stationController.text,
        vcc: _editingSection!.vcc,
        thalesChainage: double.tryParse(_chainageController.text) ?? _editingSection!.thalesChainage,
        segmentId: _editingSection!.segmentId,
        lcsMeterageStart: _editingSection!.lcsMeterageStart,
        lcsMeterageEnd: _editingSection!.lcsMeterageEnd,
        track: _editingSection!.track,
        trackSection: _editingSection!.trackSection,
        physicalAssets: _editingSection!.physicalAssets,
        notes: _editingSection!.notes,
      );

      // Save to unified data service
      await _dataService.addUserTrackSection(updatedSection);

      // Also create/update station mapping
      final mapping = LCSStationMapping(
        lcsCode: _lcsCodeController.text,
        station: _stationController.text,
        line: _selectedEditLine ?? '',
        aliases: const [],
      );
      await _dataService.addUserStationMapping(mapping);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Track section updated and saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      await _initializeData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAllTrackSections() async {
    try {
      final data = {
        'metadata': {
          'exported_at': DateTime.now().toIso8601String(),
          'version': '1.0',
          'total_track_sections': _allTrackSections.length,
        },
        'track_sections': _allTrackSections.map((ts) => ts.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/track_sections_complete_$timestamp.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)],
        text: 'Complete Track Sections Dataset');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Track sections exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track Section Training')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade800, Colors.purple.shade600],
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school),
            SizedBox(width: 8),
            Text('Track Section Training'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _exportAllTrackSections,
            tooltip: 'Export All Track Sections',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Help',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildStatsBar(),
          Expanded(child: _buildTrackSectionsList()),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: _searchMode == 'trackSection'
                        ? 'Search Track Section (5 digits)'
                        : _searchMode == 'location'
                        ? 'Search Location/Station'
                        : 'Search Chainage',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _meterageController,
                  decoration: const InputDecoration(
                    labelText: 'Meterage Range (±m)',
                    prefixIcon: Icon(Icons.straighten),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g., 50',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Search by:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'trackSection',
                      label: Text('Track Section'),
                      icon: Icon(Icons.numbers, size: 16),
                    ),
                    ButtonSegment(
                      value: 'location',
                      label: Text('Location'),
                      icon: Icon(Icons.location_on, size: 16),
                    ),
                    ButtonSegment(
                      value: 'chainage',
                      label: Text('Chainage'),
                      icon: Icon(Icons.straighten, size: 16),
                    ),
                  ],
                  selected: {_searchMode!},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() => _searchMode = selection.first);
                    _performSearch();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedLine,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Line',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Lines')),
                    ..._dataService.allLines.map((line) => DropdownMenuItem(
                      value: line,
                      child: Text(line),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedLine = value);
                    _performSearch();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.shade700,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatChip('Total', _allTrackSections.length, Colors.white),
          const SizedBox(width: 12),
          _buildStatChip('Filtered', _filteredTrackSections.length, Colors.amber),
          const Spacer(),
          Text(
            '${_filteredTrackSections.length} results',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSectionsList() {
    if (_filteredTrackSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No track sections found',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search filters',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredTrackSections.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ts = _filteredTrackSections[index];
        return _buildTrackSectionCard(ts);
      },
    );
  }

  Widget _buildTrackSectionCard(EnhancedTrackSection ts) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editTrackSection(ts),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade700, Colors.purple.shade500],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TS ${ts.trackSection}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ts.operatingLine,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editTrackSection(ts),
                    tooltip: 'Edit',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.code, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'LCS: ${ts.currentLcsCode}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 24),
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ts.newShortDescription,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Chainage: ${ts.thalesChainage.toStringAsFixed(3)}m'),
                  const SizedBox(width: 24),
                  const Icon(Icons.route, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text('Meterage: ${ts.lcsMeterageStart.toStringAsFixed(1)} - ${ts.lcsMeterageEnd.toStringAsFixed(1)}m'),
                ],
              ),
              if (ts.newLongDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ts.newLongDescription,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Track Section Training'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is the core training feature of the app!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('🎯 Purpose:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Train the app by linking track sections to locations, LCS codes, and chainages.'),
              SizedBox(height: 12),
              Text('🔍 Search Features:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Track Section: Search by 5-digit number'),
              Text('• Location: Search by station/location name'),
              Text('• Chainage: Search by absolute position'),
              Text('• Meterage: Find track sections within range (e.g., ±50m)'),
              SizedBox(height: 12),
              Text('✏️ Edit & Save:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Click any track section to edit its details. All changes are saved permanently.'),
              SizedBox(height: 12),
              Text('💾 Data Persistence:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Every edit you make teaches the app. Export your data to keep a backup!'),
              SizedBox(height: 12),
              Text('📏 Meterage Search:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Example: Search "10501" with meterage "50" finds track sections within 50m of TS 10501.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _meterageController.dispose();
    _lcsCodeController.dispose();
    _stationController.dispose();
    _chainageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
