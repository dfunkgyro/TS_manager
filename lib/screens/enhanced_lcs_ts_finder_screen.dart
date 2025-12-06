import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show LocationInfo, NearestChainageResult;
import 'package:track_sections_manager/services/enhanced_lcs_ts_service.dart';
import 'package:track_sections_manager/services/xml_export_service.dart';
// import 'package:track_sections_manager/services/data_persistence_service.dart'; // Reserved for future use
import 'package:share_plus/share_plus.dart';

/// Enhanced LCS/TS Finder with sidebars, editing, and comprehensive information
class EnhancedLcsTsFinderScreen extends StatefulWidget {
  const EnhancedLcsTsFinderScreen({super.key});

  @override
  State<EnhancedLcsTsFinderScreen> createState() => _EnhancedLcsTsFinderScreenState();
}

class _EnhancedLcsTsFinderScreenState extends State<EnhancedLcsTsFinderScreen> {
  final EnhancedLcsTsService _service = EnhancedLcsTsService();
  final XmlExportService _exportService = XmlExportService();
  // final DataPersistenceService _persistenceService = DataPersistenceService(); // Reserved for future use
  
  bool _isLoading = true;
  bool _leftSidebarOpen = true;
  bool _rightSidebarOpen = false;
  
  // Search state
  final TextEditingController _lcsQueryController = TextEditingController();
  List<LcsRecord> _lcsCandidates = [];
  LcsRecord? _selectedLcs;
  final TextEditingController _startController = TextEditingController(text: '0');
  final TextEditingController _endController = TextEditingController(text: '0');
  
  // Results state
  List<TsRecord> _results = [];
  LocationInfo? _locationInfo;
  NearestChainageResult? _chainageCorrection;
  String? _error;
  
  // Editing state
  final Map<int, Map<String, dynamic>> _edits = {};
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _lcsQueryController.addListener(() {
      _onLcsQueryChanged(_lcsQueryController.text);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _service.loadAllData();
    } catch (e) {
      setState(() => _error = 'Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onLcsQueryChanged(String query) {
    setState(() {
      _selectedLcs = null;
      
      if (query.isNotEmpty) {
        _lcsCandidates = _service.findLcsPartial(query);
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

    // Try to find LCS if not already selected
    if (_selectedLcs == null) {
      final data = _service.cachedData;
      if (data != null) {
        _selectedLcs = _service.findLcsByCode(lcsCodeInput, data);
        if (_selectedLcs == null) {
          setState(() => _error = 'LCS "$lcsCodeInput" not found.');
          return;
        }
      } else {
        setState(() => _error = 'Data not loaded.');
        return;
      }
    }

    final startM = double.tryParse(_startController.text.replaceAll(',', '.'));
    final endM = double.tryParse(_endController.text.replaceAll(',', '.'));

    if (startM == null || endM == null) {
      setState(() => _error = 'Start and End meterage must be numbers.');
      return;
    }

    // Check for nearest chainage correction
    final correction = _service.findNearestChainage(_selectedLcs!.displayCode, startM);
    if (correction.wasCorrected) {
      setState(() {
        _chainageCorrection = correction;
        _startController.text = correction.correctedMeterage.toStringAsFixed(2);
      });
    }

    final data = _service.cachedData;
    if (data == null) {
      setState(() => _error = 'Data not loaded.');
      return;
    }

    final matching = _service.findTrackSections(
      lcs: _selectedLcs!,
      startMeterage: startM,
      endMeterage: endM,
      data: data,
    );

    final locationInfo = _service.getLocationInfo(
      _selectedLcs!,
      startM,
      matching,
    );

    setState(() {
      _error = null;
      _results = matching;
      _locationInfo = locationInfo;
    });
  }

  Future<void> _exportToXml() async {
    if (_selectedLcs == null || _results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results to export')),
      );
      return;
    }

    try {
      final xml = _exportService.exportSearchResults(
        lcs: _selectedLcs!,
        startMeterage: double.parse(_startController.text),
        endMeterage: double.parse(_endController.text),
        trackSections: _results,
        locationInfo: _locationInfo,
        chainageCorrection: _chainageCorrection,
      );

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${directory.path}/lcs_ts_results_$timestamp.xml';
      final file = File(filePath);
      await file.writeAsString(xml);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: $filePath')),
        );
        
        // Share the file
        await Share.shareXFiles([XFile(filePath)], text: 'LCS/TS Search Results');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // void _editResult(int tsId, String field, dynamic value) {
  //   setState(() {
  //     _edits.putIfAbsent(tsId, () => {})[field] = value;
  //     _hasUnsavedChanges = true;
  //   });
  // }

  Future<void> _saveEdits() async {
    // Save edits to persistence
    // Implementation depends on your persistence strategy
    setState(() {
      _hasUnsavedChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved')),
    );
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
        title: const Text('Enhanced Track Section Finder'),
        actions: [
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
          // Left Sidebar - Search and Filters
          if (_leftSidebarOpen)
            Container(
              width: 300,
              color: Colors.grey[100],
              child: _buildLeftSidebar(),
            ),
          
          // Main Content
          Expanded(
            child: _buildMainContent(),
          ),
          
          // Right Sidebar - Editing and Export
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

  Widget _buildLeftSidebar() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Search & Filters',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // LCS Code Input with Partial Matching
        TextField(
          controller: _lcsQueryController,
          decoration: const InputDecoration(
            labelText: 'LCS Code',
            hintText: 'Type to search...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        
        // LCS Candidates Dropdown
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
                return ListTile(
                  dense: true,
                  title: Text(lcs.displayCode),
                  subtitle: Text(
                    lcs.shortDescription.isNotEmpty 
                        ? lcs.shortDescription 
                        : 'VCC ${lcs.vcc.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectLcs(lcs),
                );
              },
            ),
          ),
        ],
        
        // Selected LCS Info
        if (_selectedLcs != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${_selectedLcs!.displayCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(_selectedLcs!.shortDescription),
                  Text('VCC: ${_selectedLcs!.vcc.toStringAsFixed(0)}'),
                  Text('Length: ${_selectedLcs!.lcsLength.toStringAsFixed(2)} m'),
                ],
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Meterage Inputs
        TextField(
          controller: _startController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Start Meterage (m)',
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 8),
        
        TextField(
          controller: _endController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'End Meterage (m)',
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Chainage Correction Warning
        if (_chainageCorrection != null && _chainageCorrection!.wasCorrected) ...[
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 4),
                      const Text(
                        'Chainage Corrected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Original: ${_chainageCorrection!.originalMeterage.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Corrected: ${_chainageCorrection!.correctedMeterage.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Distance: ${_chainageCorrection!.distance.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
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
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
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
          // Location Information Card
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
          
          // Results Summary
          if (_results.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Track Sections (${_results.length})',
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
                          const SnackBar(content: Text('TS IDs copied to clipboard')),
                        );
                      },
                      tooltip: 'Copy TS IDs',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _exportToXml,
                      tooltip: 'Export to XML',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Results Table
            Card(
              elevation: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('TS ID')),
                    DataColumn(label: Text('Segment')),
                    DataColumn(label: Text('Chainage Start')),
                    DataColumn(label: Text('VCC')),
                    DataColumn(label: Text('Platforms')),
                  ],
                  rows: _results.map((ts) {
                    final platforms = _service.cachedData?.platformsByTs[ts.tsId] ?? [];
                    final isEdited = _edits.containsKey(ts.tsId);
                    
                    return DataRow(
                      color: isEdited 
                          ? MaterialStateProperty.all(Colors.yellow[50])
                          : null,
                      cells: [
                        DataCell(Text(ts.tsId.toString())),
                        DataCell(Text(ts.segment)),
                        DataCell(Text(ts.chainageStart.toStringAsFixed(3))),
                        DataCell(Text(ts.vcc.toStringAsFixed(0))),
                        DataCell(
                          platforms.isEmpty
                              ? const Text('-')
                              : Tooltip(
                                  message: platforms.join(', '),
                                  child: Text(
                                    platforms.join(', '),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else if (_selectedLcs != null) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No track sections found.\nAdjust meterage range and search again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Enter an LCS code and meterage range to search for track sections.',
                  textAlign: TextAlign.center,
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
          'Edit & Export',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        if (_hasUnsavedChanges) ...[
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('You have unsaved changes'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saveEdits,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Export Options
        const Text(
          'Export Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.file_download),
          title: const Text('Export to XML'),
          subtitle: const Text('Export search results'),
          onTap: _exportToXml,
        ),
        
        const Divider(),
        
        // Edit Results
        if (_results.isNotEmpty) ...[
          const Text(
            'Edit Results',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a track section from the results table to edit its properties.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
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

  @override
  void dispose() {
    _lcsQueryController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}

