import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show LocationInfo, EnhancedTrackSection;
import 'package:track_sections_manager/models/enhanced_track_data.dart';
import 'package:track_sections_manager/services/unified_data_service.dart';
import 'package:track_sections_manager/services/ai_service.dart';
import 'package:track_sections_manager/services/supabase_service.dart';
import 'package:track_sections_manager/services/xml_export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

/// Visually stunning unified search screen with all features
class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> with SingleTickerProviderStateMixin {
  final UnifiedDataService _dataService = UnifiedDataService();
  final AIService _aiService = AIService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  bool _leftSidebarOpen = true;
  bool _rightSidebarOpen = true;

  // Connection status
  bool _aiConnected = false;
  bool _supabaseConnected = false;

  // Search state
  final TextEditingController _unifiedSearchController = TextEditingController();
  String? _selectedLine;
  String? _selectedDistrict;
  String? _selectedCircle;
  String? _selectedLcsCode;
  String? _selectedStation;

  // Results state
  List<UnifiedSearchResult> _unifiedResults = [];
  String? _error;

  // Animation controller for stunning effects
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Known data for dropdowns
  List<String> _allKnownLcsCodes = [];
  List<String> _allKnownStations = [];
  List<String> _allKnownLines = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);
    try {
      // Load unified data
      await _dataService.loadAllData();

      // Initialize AI service
      try {
        await _aiService.initialize();
        _aiConnected = _aiService.isConnected;
      } catch (e) {
        debugPrint('AI service initialization failed: $e');
        _aiConnected = false;
      }

      // Check Supabase connection
      try {
        _supabaseConnected = _supabaseService.isInitialized;
      } catch (e) {
        debugPrint('Supabase check failed: $e');
        _supabaseConnected = false;
      }

      // Load all known data for dropdowns
      _allKnownLcsCodes = _dataService.allLcsCodes;
      _allKnownStations = _dataService.allStations;
      _allKnownLines = _dataService.allLines;

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  void _performUnifiedSearch() {
    final query = _unifiedSearchController.text.trim();
    if (query.isEmpty && _selectedLcsCode == null && _selectedStation == null) {
      setState(() => _error = 'Please enter a search query or select filters');
      return;
    }

    setState(() {
      _error = null;
      _unifiedResults.clear();
    });

    final results = <UnifiedSearchResult>[];

    // Search across all data sources

    // 1. Search LCS codes
    if (query.isNotEmpty) {
      final lcsMatches = _dataService.findLcsPartial(query);
      for (final lcs in lcsMatches) {
        final mapping = _dataService.getStationMapping(lcs.displayCode);
        if (_matchesFilters(mapping?.line, mapping?.station)) {
          results.add(UnifiedSearchResult(
            type: ResultType.lcsCode,
            title: lcs.displayCode,
            subtitle: '${mapping?.station ?? lcs.shortDescription} - ${mapping?.line ?? "Unknown"}',
            data: lcs,
            source: 'LCS Database',
            relevanceScore: _calculateRelevance(query, lcs.displayCode),
          ));
        }
      }
    }

    // 2. Search by selected LCS code
    if (_selectedLcsCode != null) {
      final lcs = _dataService.findLcsByCode(_selectedLcsCode!);
      if (lcs != null) {
        final trackSections = _dataService.getTrackSectionsByLcs(_selectedLcsCode!);
        for (final ts in trackSections) {
          if (_matchesFilters(ts.operatingLine, null)) {
            results.add(UnifiedSearchResult(
              type: ResultType.trackSection,
              title: 'Track Section ${ts.trackSection}',
              subtitle: '${ts.operatingLine} - ${ts.newShortDescription}',
              data: ts,
              source: 'Track Sections Database',
              relevanceScore: 100,
            ));
          }
        }
      }
    }

    // 3. Search stations
    if (query.isNotEmpty || _selectedStation != null) {
      final searchStation = _selectedStation ?? query;
      final stationMatches = _dataService.allStationMappings
          .where((m) => m.station.toLowerCase().contains(searchStation.toLowerCase()))
          .toList();

      for (final mapping in stationMatches) {
        if (_matchesFilters(mapping.line, mapping.station)) {
          results.add(UnifiedSearchResult(
            type: ResultType.station,
            title: mapping.station,
            subtitle: '${mapping.line} - ${mapping.lcsCode}',
            data: mapping,
            source: 'Station Mappings',
            relevanceScore: _calculateRelevance(searchStation, mapping.station),
          ));
        }
      }
    }

    // 4. Search track sections by line
    if (_selectedLine != null) {
      final lineSections = _dataService.getTrackSectionsByLine(_selectedLine!);
      for (final ts in lineSections) {
        results.add(UnifiedSearchResult(
          type: ResultType.trackSection,
          title: 'Track Section ${ts.trackSection}',
          subtitle: '${ts.currentLcsCode} - ${ts.newShortDescription}',
          data: ts,
          source: 'Track Sections by Line',
          relevanceScore: 90,
        ));
      }
    }

    // Sort by relevance
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    setState(() {
      _unifiedResults = results;
      if (results.isEmpty) {
        _error = 'No results found. Would you like to add this data?';
      }
    });
  }

  bool _matchesFilters(String? line, String? station) {
    if (_selectedLine != null && line != _selectedLine) return false;
    if (_selectedStation != null && station != _selectedStation) return false;
    return true;
  }

  int _calculateRelevance(String query, String target) {
    final q = query.toLowerCase();
    final t = target.toLowerCase();
    if (t == q) return 100;
    if (t.startsWith(q)) return 90;
    if (t.contains(q)) return 70;
    return 50;
  }

  Future<void> _exportAllData() async {
    try {
      final data = _dataService.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/ts_manager_export_$timestamp.json');
      await file.writeAsString(jsonString);

      // Also export as XML
      final xmlService = XmlExportService();
      final xmlFile = File('${directory.path}/ts_manager_export_$timestamp.xml');
      await xmlFile.writeAsString(xmlService.exportToXml(data));

      await Share.shareXFiles([XFile(file.path), XFile(xmlFile.path)],
        text: 'TS Manager Data Export');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully (JSON & XML)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'xml'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        Map<String, dynamic> data;
        if (result.files.single.extension == 'json') {
          data = jsonDecode(content);
        } else {
          // Parse XML and convert to JSON format
          final xmlService = XmlExportService();
          data = xmlService.importFromXml(content);
        }

        await _dataService.importData(data);
        await _dataService.loadAllData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data imported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddDataDialog() {
    final lcsCodeController = TextEditingController(text: _unifiedSearchController.text);
    final stationController = TextEditingController();
    String? selectedLine;
    final tsIdsController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add Missing Data'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lcsCodeController,
                  decoration: const InputDecoration(
                    labelText: 'LCS Code *',
                    prefixIcon: Icon(Icons.code),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stationController,
                  decoration: const InputDecoration(
                    labelText: 'Station/Location Name',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLine,
                  decoration: const InputDecoration(
                    labelText: 'Line/District',
                    prefixIcon: Icon(Icons.train),
                    border: OutlineInputBorder(),
                  ),
                  items: _allKnownLines.map((line) => DropdownMenuItem(
                    value: line,
                    child: Text(line),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedLine = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tsIdsController,
                  decoration: const InputDecoration(
                    labelText: 'Track Section IDs (comma-separated)',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 10046, 10047, 10048',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (lcsCodeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('LCS Code is required')),
                  );
                  return;
                }

                try {
                  final mapping = LCSStationMapping(
                    lcsCode: lcsCodeController.text,
                    station: stationController.text.isEmpty ? 'Unknown' : stationController.text,
                    line: selectedLine ?? 'Unknown',
                    aliases: const [],
                  );

                  await _dataService.addUserStationMapping(mapping);

                  if (tsIdsController.text.isNotEmpty) {
                    final tsIds = tsIdsController.text
                        .split(',')
                        .map((e) => int.tryParse(e.trim()))
                        .where((id) => id != null)
                        .cast<int>()
                        .toList();

                    if (tsIds.isNotEmpty) {
                      await _dataService.linkLcsToTrackSections(lcsCodeController.text, tsIds);
                    }
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data added successfully and saved'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  _performUnifiedSearch();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade600,
                Colors.cyan.shade400,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Loading Track Sections Manager...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.cyan.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 28),
            SizedBox(width: 8),
            Text('Unified Track Sections Search'),
          ],
        ),
        actions: [
          // AI Connection Indicator
          _buildConnectionIndicator(
            'AI',
            _aiConnected,
            Icons.psychology,
            Colors.purple,
          ),
          const SizedBox(width: 8),
          // Supabase Connection Indicator
          _buildConnectionIndicator(
            'DB',
            _supabaseConnected,
            Icons.storage,
            Colors.green,
          ),
          const SizedBox(width: 16),
          // Sidebar toggles
          IconButton(
            icon: Icon(_leftSidebarOpen ? Icons.chevron_left : Icons.menu_open),
            onPressed: () => setState(() => _leftSidebarOpen = !_leftSidebarOpen),
            tooltip: 'Toggle search filters',
          ),
          IconButton(
            icon: Icon(_rightSidebarOpen ? Icons.chevron_right : Icons.menu),
            onPressed: () => setState(() => _rightSidebarOpen = !_rightSidebarOpen),
            tooltip: 'Toggle data management',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - Search & Filters
          if (_leftSidebarOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 350,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50,
                    Colors.cyan.shade50,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: _buildLeftSidebar(),
            ),

          // Main Content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: _buildMainContent(),
            ),
          ),

          // Right Sidebar - Data Management
          if (_rightSidebarOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 350,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.orange.shade50,
                    Colors.amber.shade50,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: _buildRightSidebar(),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(String label, bool connected, IconData icon, Color color) {
    return Tooltip(
      message: '$label: ${connected ? "Connected" : "Disconnected"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: connected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: connected ? color : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: connected ? color : Colors.grey),
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: connected ? color : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: connected ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: connected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.cyan.shade500],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.filter_list, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Search & Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Unified Search Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _unifiedSearchController,
            decoration: const InputDecoration(
              labelText: 'Unified Search',
              hintText: 'Search anything...',
              prefixIcon: Icon(Icons.search, color: Colors.blue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _performUnifiedSearch(),
          ),
        ),
        const SizedBox(height: 20),

        // Quick Filters Section
        const Text(
          'Quick Filters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // LCS Code Dropdown
        _buildStyledDropdown(
          label: 'Known LCS Codes',
          icon: Icons.code,
          value: _selectedLcsCode,
          items: _allKnownLcsCodes,
          onChanged: (value) => setState(() => _selectedLcsCode = value),
          color: Colors.blue,
        ),
        const SizedBox(height: 12),

        // Station Dropdown
        _buildStyledDropdown(
          label: 'Known Stations',
          icon: Icons.location_on,
          value: _selectedStation,
          items: _allKnownStations,
          onChanged: (value) => setState(() => _selectedStation = value),
          color: Colors.green,
        ),
        const SizedBox(height: 12),

        // Line/District Filter
        _buildStyledDropdown(
          label: 'Line/District',
          icon: Icons.train,
          value: _selectedLine,
          items: _allKnownLines,
          onChanged: (value) => setState(() => _selectedLine = value),
          color: Colors.orange,
        ),
        const SizedBox(height: 24),

        // Search Button
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.cyan.shade500],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _performUnifiedSearch,
            icon: const Icon(Icons.search, size: 24),
            label: const Text(
              'Search All Sources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Clear Filters Button
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _unifiedSearchController.clear();
              _selectedLcsCode = null;
              _selectedStation = null;
              _selectedLine = null;
              _selectedDistrict = null;
              _selectedCircle = null;
              _unifiedResults.clear();
              _error = null;
            });
          },
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear All Filters'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),

        // Error Display
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error!.contains('add this data')) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _showAddDataDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Missing Data'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: color),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text('All ${label}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
          ...items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )),
        ],
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results Header
            if (_unifiedResults.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.cyan.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_unifiedResults.length} Results Found',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'From all data sources',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
                      onPressed: () {
                        final text = _unifiedResults.map((r) => '${r.title}: ${r.subtitle}').join('\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Results copied to clipboard')),
                        );
                      },
                      tooltip: 'Copy results',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Results List
              ..._unifiedResults.map((result) => _buildResultCard(result)),
            ] else ...[
              // Empty State
              Center(
                child: Container(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 120,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Start Your Search',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Use the unified search or filters on the left\nto find LCS codes, stations, track sections, and more',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Search Tips',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTip('Search by LCS code (e.g., M187, BAK/A)'),
                            _buildTip('Filter by line or district'),
                            _buildTip('Select from known stations dropdown'),
                            _buildTip('Add missing data when not found'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(UnifiedSearchResult result) {
    IconData icon;
    Color color;

    switch (result.type) {
      case ResultType.lcsCode:
        icon = Icons.code;
        color = Colors.blue;
        break;
      case ResultType.trackSection:
        icon = Icons.route;
        color = Colors.green;
        break;
      case ResultType.station:
        icon = Icons.location_on;
        color = Colors.orange;
        break;
      case ResultType.platform:
        icon = Icons.platform;
        color = Colors.purple;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.source,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                        Text(
                          ' ${result.relevanceScore}% match',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () {
                  // Show details dialog
                  _showResultDetails(result);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDetails(UnifiedSearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getIconForType(result.type), color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(result.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.subtitle,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Source', result.source),
              _buildDetailRow('Type', result.type.toString().split('.').last),
              _buildDetailRow('Relevance', '${result.relevanceScore}%'),
              const SizedBox(height: 16),
              if (result.data != null) ...[
                const Text(
                  'Additional Data:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.data.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  IconData _getIconForType(ResultType type) {
    switch (type) {
      case ResultType.lcsCode:
        return Icons.code;
      case ResultType.trackSection:
        return Icons.route;
      case ResultType.station:
        return Icons.location_on;
      case ResultType.platform:
        return Icons.platform;
    }
  }

  Widget _buildRightSidebar() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.amber.shade500],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.settings, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Data Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Statistics Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Database Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatRow('LCS Codes', _allKnownLcsCodes.length, Icons.code, Colors.blue),
              _buildStatRow('Stations', _allKnownStations.length, Icons.location_on, Colors.green),
              _buildStatRow('Lines', _allKnownLines.length, Icons.train, Icons.orange),
              _buildStatRow('Track Sections', _dataService.allTrackSections.length, Icons.route, Colors.purple),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Add Missing Data
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.teal.shade500],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _showAddDataDialog,
            icon: const Icon(Icons.add_circle, size: 24),
            label: const Text(
              'Add Missing Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Export/Import Section
        const Text(
          'Data Export/Import',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _exportAllData,
          icon: const Icon(Icons.upload_file),
          label: const Text('Export All Data (JSON & XML)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _importData,
          icon: const Icon(Icons.download),
          label: const Text('Import Data'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
        const SizedBox(height: 24),

        // View All Data Section
        const Text(
          'Browse All Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        _buildBrowseButton(
          'View All LCS Codes',
          Icons.code,
          Colors.blue,
          () => _showAllDataDialog('LCS Codes', _allKnownLcsCodes),
        ),
        const SizedBox(height: 8),

        _buildBrowseButton(
          'View All Stations',
          Icons.location_on,
          Colors.green,
          () => _showAllDataDialog('Stations', _allKnownStations),
        ),
        const SizedBox(height: 8),

        _buildBrowseButton(
          'View All Lines',
          Icons.train,
          Colors.orange,
          () => _showAllDataDialog('Lines', _allKnownLines),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: color, width: 1.5),
        foregroundColor: color,
      ),
    );
  }

  void _showAllDataDialog(String title, List<String> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.list, color: Colors.blue),
            const SizedBox(width: 8),
            Text('$title (${items.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${index + 1}'),
                ),
                title: Text(items[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      if (title.contains('LCS')) {
                        _selectedLcsCode = items[index];
                      } else if (title.contains('Station')) {
                        _selectedStation = items[index];
                      } else if (title.contains('Line')) {
                        _selectedLine = items[index];
                      }
                    });
                    _performUnifiedSearch();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _unifiedSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Model for unified search results
class UnifiedSearchResult {
  final ResultType type;
  final String title;
  final String subtitle;
  final dynamic data;
  final String source;
  final int relevanceScore;

  UnifiedSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.data,
    required this.source,
    required this.relevanceScore,
  });
}

enum ResultType {
  lcsCode,
  trackSection,
  station,
  platform,
}
