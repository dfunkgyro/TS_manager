// screens/data_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/enhanced_track_data.dart';
import '../models/track_data.dart';
import '../services/data_persistence_service.dart';
import '../services/enhanced_data_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({Key? key}) : super(key: key);

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final DataPersistenceService _persistenceService = DataPersistenceService();
  final EnhancedDataService _dataService = EnhancedDataService();

  List<LCSStationMapping> _customMappings = [];
  List<TrackSection> _customTrackSections = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mappings = await _persistenceService.loadStationMappings();
      final sections = await _persistenceService.loadTrackSections();

      setState(() {
        _customMappings = mappings;
        _customTrackSections = sections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddMappingDialog() async {
    final result = await showDialog<LCSStationMapping>(
      context: context,
      builder: (context) => const _MappingEditorDialog(),
    );

    if (result != null) {
      await _persistenceService.addOrUpdateStationMapping(result);
      _loadData();
      _showSnackBar('Station mapping added successfully');
    }
  }

  Future<void> _showEditMappingDialog(LCSStationMapping mapping) async {
    final result = await showDialog<LCSStationMapping>(
      context: context,
      builder: (context) => _MappingEditorDialog(mapping: mapping),
    );

    if (result != null) {
      await _persistenceService.addOrUpdateStationMapping(result);
      _loadData();
      _showSnackBar('Station mapping updated successfully');
    }
  }

  Future<void> _deleteMapping(LCSStationMapping mapping) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete mapping for ${mapping.station} (${mapping.lcsCode})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _persistenceService.deleteStationMapping(mapping.lcsCode);
      _loadData();
      _showSnackBar('Station mapping deleted');
    }
  }

  Future<void> _exportToXml() async {
    try {
      final xmlContent = _persistenceService.exportToXml(_customMappings);

      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${directory.path}/lcs_mappings_export_$timestamp.xml';

      final file = File(filePath);
      await file.writeAsString(xmlContent);

      _showSnackBar('Exported to: $filePath');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    }
  }

  Future<void> _exportTrackSectionsToJson() async {
    try {
      final jsonContent = _persistenceService.exportTrackSectionsToJson(_customTrackSections);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = '${directory.path}/track_sections_export_$timestamp.json';

      final file = File(filePath);
      await file.writeAsString(jsonContent);

      _showSnackBar('Exported to: $filePath');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    }
  }

  Future<void> _importFromXml() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // TODO: Parse XML and import mappings
        _showSnackBar('Import from XML is under development');
      }
    } catch (e) {
      _showSnackBar('Import failed: $e', isError: true);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Custom Data'),
        content: const Text('This will delete all custom station mappings and track sections. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _persistenceService.clearAllCustomData();
      _loadData();
      _showSnackBar('All custom data cleared');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export_xml':
                  _exportToXml();
                  break;
                case 'export_json':
                  _exportTrackSectionsToJson();
                  break;
                case 'import_xml':
                  _importFromXml();
                  break;
                case 'clear_all':
                  _clearAllData();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_xml',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Export to XML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Export Track Sections'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_xml',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Import from XML'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Data', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Station Mappings', icon: Icon(Icons.train)),
                          Tab(text: 'Track Sections', icon: Icon(Icons.route)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildStationMappingsTab(),
                            _buildTrackSectionsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMappingDialog,
        tooltip: 'Add Station Mapping',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStationMappingsTab() {
    if (_customMappings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No custom station mappings yet'),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to add a new mapping',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _customMappings.length,
      itemBuilder: (context, index) {
        final mapping = _customMappings[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(mapping.line[0]),
            ),
            title: Text(mapping.station, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LCS Code: ${mapping.lcsCode}'),
                Text('Line: ${mapping.line}'),
                if (mapping.branch != null) Text('Branch: ${mapping.branch}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditMappingDialog(mapping),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteMapping(mapping),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildTrackSectionsTab() {
    if (_customTrackSections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No custom track sections yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _customTrackSections.length,
      itemBuilder: (context, index) {
        final section = _customTrackSections[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(section.lcsCode, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.newShortDescription),
                Text('Meterage: ${section.lcsMeterageStart} - ${section.lcsMeterageEnd}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _MappingEditorDialog extends StatefulWidget {
  final LCSStationMapping? mapping;

  const _MappingEditorDialog({this.mapping});

  @override
  State<_MappingEditorDialog> createState() => _MappingEditorDialogState();
}

class _MappingEditorDialogState extends State<_MappingEditorDialog> {
  late TextEditingController _lcsCodeController;
  late TextEditingController _stationController;
  late TextEditingController _lineController;
  late TextEditingController _branchController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _zoneController;

  @override
  void initState() {
    super.initState();
    _lcsCodeController = TextEditingController(text: widget.mapping?.lcsCode ?? '');
    _stationController = TextEditingController(text: widget.mapping?.station ?? '');
    _lineController = TextEditingController(text: widget.mapping?.line ?? '');
    _branchController = TextEditingController(text: widget.mapping?.branch ?? '');
    _latitudeController = TextEditingController(text: widget.mapping?.latitude?.toString() ?? '');
    _longitudeController = TextEditingController(text: widget.mapping?.longitude?.toString() ?? '');
    _zoneController = TextEditingController(text: widget.mapping?.zone?.toString() ?? '');
  }

  @override
  void dispose() {
    _lcsCodeController.dispose();
    _stationController.dispose();
    _lineController.dispose();
    _branchController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_lcsCodeController.text.isEmpty ||
        _stationController.text.isEmpty ||
        _lineController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LCS Code, Station, and Line are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final mapping = LCSStationMapping(
      lcsCode: _lcsCodeController.text.trim(),
      station: _stationController.text.trim(),
      line: _lineController.text.trim(),
      branch: _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
      zone: int.tryParse(_zoneController.text.trim()),
    );

    Navigator.pop(context, mapping);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mapping == null ? 'Add Station Mapping' : 'Edit Station Mapping'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _lcsCodeController,
                decoration: const InputDecoration(
                  labelText: 'LCS Code *',
                  hintText: 'e.g., D011',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stationController,
                decoration: const InputDecoration(
                  labelText: 'Station Name *',
                  hintText: 'e.g., Upminster',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lineController,
                decoration: const InputDecoration(
                  labelText: 'Line *',
                  hintText: 'e.g., District Line',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: 'Branch (optional)',
                  hintText: 'e.g., Upminster Branch',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '51.5191',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-0.1880',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _zoneController,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                  hintText: '1',
                ),
                keyboardType: TextInputType.number,
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
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
