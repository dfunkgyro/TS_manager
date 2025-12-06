import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show LocationInfo;
import 'package:track_sections_manager/models/enhanced_track_data.dart' hide EnhancedTrackSection;
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show EnhancedTrackSection;
import 'package:track_sections_manager/services/unified_data_service.dart';
import 'package:track_sections_manager/services/ai_service.dart';
import 'package:track_sections_manager/services/supabase_service.dart';
import 'package:track_sections_manager/services/xml_export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

/// Comprehensive finder screen with unified data, AI, user input, and connection status
class ComprehensiveFinderScreen extends StatefulWidget {
  const ComprehensiveFinderScreen({super.key});

  @override
  State<ComprehensiveFinderScreen> createState() => _ComprehensiveFinderScreenState();
}

class _ComprehensiveFinderScreenState extends State<ComprehensiveFinderScreen> {
  final UnifiedDataService _dataService = UnifiedDataService();
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _isLoading = true;
  bool _leftSidebarOpen = true;
  bool _rightSidebarOpen = false;
  
  // Connection status
  bool _aiConnected = false;
  bool _supabaseConnected = false;
  
  // Search state
  final TextEditingController _lcsQueryController = TextEditingController();
  String? _selectedLine;
  String? _selectedStation;
  List<LcsRecord> _lcsCandidates = [];
  LcsRecord? _selectedLcs;
  final TextEditingController _startController = TextEditingController(text: '0');
  final TextEditingController _endController = TextEditingController(text: '0');
  
  // Results state
  List<TsRecord> _results = [];
  List<EnhancedTrackSection> _enhancedResults = [];
  LocationInfo? _locationInfo;
  String? _error;
  String? _selectedLineFilter;
  
  // User input state
  final Map<String, dynamic> _newLcsMapping = {};
  final Map<String, dynamic> _newTrackSectionLink = {};

  @override
  void initState() {
    super.initState();
    _lcsQueryController.addListener(() => _onLcsQueryChanged(_lcsQueryController.text));
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);
    try {
      // Load unified data
      await _dataService.loadAllData();
      
      // Initialize AI service
      await _aiService.initialize();
      _aiConnected = _aiService.isConnected;
      
      // Check Supabase connection
      _supabaseConnected = _supabaseService.isInitialized;
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  void _onLcsQueryChanged(String query) {
    setState(() {
      _selectedLcs = null;
      if (query.isNotEmpty) {
        _lcsCandidates = _dataService.findLcsPartial(query);
        // Filter by selected line if any
        if (_selectedLine != null) {
          _lcsCandidates = _lcsCandidates.where((lcs) {
            final mapping = _dataService.getStationMapping(lcs.displayCode);
            return mapping?.line == _selectedLine;
          }).toList();
        }
      } else {
        _lcsCandidates = [];
      }
    });
  }

  void _selectLcs(LcsRecord lcs) {
    setState(() {
      _selectedLcs = lcs;
      _lcsQueryController.text = lcs.displayCode;
      _lcsCandidates = [];
    });
  }

  void _runSearch() {
    final lcsCodeInput = _lcsQueryController.text.trim();
    if (lcsCodeInput.isEmpty) {
      setState(() => _error = 'Please enter an LCS code.');
      return;
    }

    final lcs = _selectedLcs ?? _dataService.findLcsByCode(lcsCodeInput);
    if (lcs == null) {
      setState(() => _error = 'LCS "$lcsCodeInput" not found. Would you like to add it?');
      _showAddDataDialog();
      return;
    }

    final startM = double.tryParse(_startController.text.replaceAll(',', '.'));
    final endM = double.tryParse(_endController.text.replaceAll(',', '.'));

    if (startM == null || endM == null) {
      setState(() => _error = 'Start and End meterage must be numbers.');
      return;
    }

    // Find track sections
    final matching = _dataService.findTrackSectionsByMeterage(
      lcs: lcs,
      startMeterage: startM,
      endMeterage: endM,
    );

    // Get enhanced track sections
    final enhancedSections = _dataService.getTrackSectionsByLcs(lcs.displayCode);
    
    // Filter by line if selected
    if (_selectedLineFilter != null) {
      _enhancedResults = enhancedSections
          .where((s) => s.operatingLine == _selectedLineFilter)
          .toList();
    } else {
      _enhancedResults = enhancedSections;
    }

    // Get location info
    final locationInfo = _dataService.getLocationInfo(lcs, startM, matching);

    setState(() {
      _error = null;
      _results = matching;
      _locationInfo = locationInfo;
    });
  }

  Future<void> _addMissingLcs() async {
    if (_newLcsMapping['lcsCode'] == null || _newLcsMapping['lcsCode'].toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LCS Code is required')),
      );
      return;
    }

    try {
      final mapping = LCSStationMapping(
        lcsCode: _newLcsMapping['lcsCode'].toString(),
        station: _newLcsMapping['station']?.toString() ?? 'Unknown',
        line: _newLcsMapping['line']?.toString() ?? 'Unknown',
        aliases: const [],
      );
      
      await _dataService.addUserStationMapping(mapping);
      
      // Link to track sections if provided
      if (_newTrackSectionLink['trackSections'] != null) {
        final tsIds = (_newTrackSectionLink['trackSections'] as List)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((id) => id > 0)
            .toList();
        
        if (tsIds.isNotEmpty) {
          await _dataService.linkLcsToTrackSections(mapping.lcsCode, tsIds);
        }
      }
      
      setState(() {
        _newLcsMapping.clear();
        _newTrackSectionLink.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LCS mapping added successfully')),
      );
      
      // Re-run search
      _runSearch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding LCS: $e')),
      );
    }
  }

  Future<void> _exportAllData() async {
    try {
      final data = _dataService.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/track_sections_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      await Share.shareXFiles([XFile(file.path)]);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Track Section Finder'),
        actions: [
          // Connection status indicators
          _buildConnectionIndicator('AI', _aiConnected, Colors.blue),
          const SizedBox(width: 8),
          _buildConnectionIndicator('DB', _supabaseConnected, Colors.green),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(_leftSidebarOpen ? Icons.chevron_left : Icons.chevron_right),
            onPressed: () => setState(() => _leftSidebarOpen = !_leftSidebarOpen),
            tooltip: 'Toggle left sidebar',
          ),
          IconButton(
            icon: Icon(_rightSidebarOpen ? Icons.chevron_right : Icons.chevron_left),
            onPressed: () => setState(() => _rightSidebarOpen = !_rightSidebarOpen),
            tooltip: 'Toggle right sidebar',
          ),
        ],
      ),
      body: Row(
        children: [
          if (_leftSidebarOpen)
            Container(
              width: 320,
              color: Colors.grey[100],
              child: _buildLeftSidebar(),
            ),
          Expanded(child: _buildMainContent()),
          if (_rightSidebarOpen)
            Container(
              width: 350,
              color: Colors.grey[100],
              child: _buildRightSidebar(),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(String label, bool connected, Color color) {
    return Tooltip(
      message: '$label: ${connected ? "Connected" : "Disconnected"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: connected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: connected ? color : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: connected ? color : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Search & Filters',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Line Filter Dropdown
        DropdownButtonFormField<String>(
          value: _selectedLine,
          decoration: const InputDecoration(
            labelText: 'Filter by Line',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.train),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Lines')),
            ..._dataService.allLines.map((line) => DropdownMenuItem(
              value: line,
              child: Text(line),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedLine = value;
              _selectedLineFilter = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Station Filter Dropdown
        DropdownButtonFormField<String>(
          value: _selectedStation,
          decoration: const InputDecoration(
            labelText: 'Filter by Station',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Stations')),
            ..._dataService.allStations.map((station) => DropdownMenuItem(
              value: station,
              child: Text(station),
            )),
          ],
          onChanged: (value) {
            setState(() => _selectedStation = value);
          },
        ),
        const SizedBox(height: 16),
        
        // LCS Code Input
        TextField(
          controller: _lcsQueryController,
          decoration: const InputDecoration(
            labelText: 'LCS Code',
            hintText: 'Type to search...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        
        // LCS Candidates
        if (_lcsCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Matching LCS Codes:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _lcsCandidates.length,
              itemBuilder: (context, index) {
                final lcs = _lcsCandidates[index];
                final mapping = _dataService.getStationMapping(lcs.displayCode);
                return ListTile(
                  dense: true,
                  title: Text(lcs.displayCode),
                  subtitle: mapping != null ? Text('${mapping.station} - ${mapping.line}') : null,
                  onTap: () => _selectLcs(lcs),
                );
              },
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Meterage inputs
        TextField(
          controller: _startController,
          decoration: const InputDecoration(
            labelText: 'Start Meterage (m)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _endController,
          decoration: const InputDecoration(
            labelText: 'End Meterage (m)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        
        const SizedBox(height: 16),
        
        // Search Button
        FilledButton.icon(
          onPressed: _runSearch,
          icon: const Icon(Icons.search),
          label: const Text('Find Track Sections'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                if (_error!.contains('not found')) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _showAddDataDialog,
                    child: const Text('Add'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Information
          if (_locationInfo != null) ...[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Information',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Station', _locationInfo!.station),
                    _buildInfoRow('Line', _locationInfo!.line),
                    _buildInfoRow('LCS Code', _locationInfo!.lcsCode),
                    _buildInfoRow('Chainage', _locationInfo!.chainage.toStringAsFixed(3)),
                    _buildInfoRow('Meterage', '${_locationInfo!.meterage.toStringAsFixed(3)} m'),
                    if (_locationInfo!.platforms.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Platforms:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Wrap(
                        spacing: 8,
                        children: _locationInfo!.platforms
                            .map((p) => Chip(label: Text(p)))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Results
          if (_results.isNotEmpty || _enhancedResults.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Track Sections (${_results.length} basic, ${_enhancedResults.length} enhanced)',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        final tsIds = _results.map((ts) => ts.tsId.toString()).join(', ');
                        Clipboard.setData(ClipboardData(text: tsIds));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('TS IDs copied')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _exportAllData,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Enhanced Track Sections
            if (_enhancedResults.isNotEmpty) ...[
              const Text(
                'Enhanced Track Sections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._enhancedResults.map((section) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('TS ${section.trackSection}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LCS: ${section.currentLcsCode} / ${section.legacyLcsCode}'),
                      Text('Line: ${section.operatingLine}'),
                      Text('Description: ${section.newShortDescription}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            // Basic Track Sections
            if (_results.isNotEmpty) ...[
              const Text(
                'Basic Track Sections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DataTable(
                columns: const [
                  DataColumn(label: Text('TS ID')),
                  DataColumn(label: Text('Segment')),
                  DataColumn(label: Text('Chainage Start')),
                  DataColumn(label: Text('Platforms')),
                ],
                rows: _results.map((ts) {
                  final platforms = _dataService.getPlatformsForTrackSection(ts.tsId);
                  return DataRow(
                    cells: [
                      DataCell(Text(ts.tsId.toString())),
                      DataCell(Text(ts.segment)),
                      DataCell(Text(ts.chainageStart.toStringAsFixed(3))),
                      DataCell(platforms.isEmpty 
                        ? const Text('-')
                        : Text(platforms.join(', '))),
                    ],
                  );
                }).toList(),
              ),
            ],
          ] else if (_error == null) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Enter an LCS code and meterage range to search',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Data Management',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Add Missing Data Button
        FilledButton.icon(
          onPressed: _showAddDataDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Missing Data'),
        ),
        const SizedBox(height: 16),
        
        // Export/Import
        const Text(
          'Export/Import',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _exportAllData,
          icon: const Icon(Icons.upload),
          label: const Text('Export All Data'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            // Import functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import feature coming soon')),
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('Import Data'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAddDataDialog() {
    final lcsCodeController = TextEditingController(text: _lcsQueryController.text);
    final stationController = TextEditingController();
    final lineController = TextEditingController();
    final tsIdsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Missing LCS Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lcsCodeController,
                decoration: const InputDecoration(
                  labelText: 'LCS Code *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stationController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                  labelText: 'Line',
                  border: OutlineInputBorder(),
                ),
                items: _dataService.allLines.map((line) => DropdownMenuItem(
                  value: line,
                  child: Text(line),
                )).toList(),
                onChanged: (value) => lineController.text = value ?? '',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tsIdsController,
                decoration: const InputDecoration(
                  labelText: 'Track Section IDs (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 10046, 10047, 10048',
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
          FilledButton(
            onPressed: () {
              _newLcsMapping['lcsCode'] = lcsCodeController.text;
              _newLcsMapping['station'] = stationController.text;
              _newLcsMapping['line'] = lineController.text;
              
              if (tsIdsController.text.isNotEmpty) {
                _newTrackSectionLink['trackSections'] = tsIdsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
              
              Navigator.pop(context);
              _addMissingLcs();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lcsQueryController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}

