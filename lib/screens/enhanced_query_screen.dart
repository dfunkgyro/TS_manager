// screens/enhanced_query_screen.dart
import 'package:flutter/material.dart';
import 'package:track_sections_manager/models/enhanced_track_data.dart';
import 'package:track_sections_manager/services/enhanced_data_service.dart';
import 'package:track_sections_manager/widgets/station_card.dart';
import 'package:track_sections_manager/widgets/network_map.dart';

class EnhancedQueryScreen extends StatefulWidget {
  const EnhancedQueryScreen({super.key});

  @override
  _EnhancedQueryScreenState createState() => _EnhancedQueryScreenState();
}

class _EnhancedQueryScreenState extends State<EnhancedQueryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _meterageController = TextEditingController();
  final TextEditingController _lcsController = TextEditingController();
  
  EnhancedQueryResult? _result;
  List<LCSStationMapping> _searchResults = [];
  bool _isLoading = false;
  String _activeTab = 'search';

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      final results = EnhancedDataService().searchStations(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    });
  }

  void _searchByMeterage() {
    final meterage = double.tryParse(_meterageController.text);
    if (meterage == null) return;

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      final result = EnhancedDataService().enhancedSearchByMeterage(meterage);
      setState(() {
        _result = result;
        _isLoading = false;
        _activeTab = 'results';
      });
    });
  }

  void _searchByLcs() {
    final lcsCode = _lcsController.text.trim();
    if (lcsCode.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Future.delayed(const Duration(milliseconds: 500), () {
        final result = EnhancedDataService().enhancedSearchByLcsCode(lcsCode);
        setState(() {
          _result = result;
          _isLoading = false;
          _activeTab = 'results';
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Track Query'),
        elevation: 4,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            child: TabBar(
              controller: TabController(
                length: 3,
                vsync: ScaffoldState(),
                initialIndex: _activeTab == 'search' ? 0 : 
                            _activeTab == 'meterage' ? 1 : 2,
              ),
              onTap: (index) {
                setState(() {
                  _activeTab = ['search', 'meterage', 'lcs'][index];
                });
              },
              tabs: const [
                Tab(icon: Icon(Icons.search), text: 'Search'),
                Tab(icon: Icon(Icons.speed), text: 'Meterage'),
                Tab(icon: Icon(Icons.qr_code), text: 'LCS Code'),
              ],
            ),
          ),
          Expanded(
            child: _buildActiveTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_activeTab) {
      case 'search':
        return _buildSearchTab();
      case 'meterage':
        return _buildMeterageTab();
      case 'lcs':
        return _buildLcsTab();
      case 'results':
        return _buildResultsTab();
      default:
        return _buildSearchTab();
    }
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Stations or LCS Codes',
                      hintText: 'e.g., Baker Street or D011',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults.clear();
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final station = _searchResults[index];
                  return StationCard(mapping: station);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeterageTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _meterageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Enter Meterage',
                      hintText: 'e.g., 15000.5',
                      prefixIcon: const Icon(Icons.speed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchByMeterage,
                    icon: const Icon(Icons.search),
                    label: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Find Nearest Location'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLcsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _lcsController,
                    decoration: InputDecoration(
                      labelText: 'Enter LCS Code',
                      hintText: 'e.g., D011 or M173',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchByLcs,
                    icon: const Icon(Icons.search),
                    label: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Find Station'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_result == null) return const Center(child: Text('No results'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main result card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_result!.nearestStation != null) ...[
                    ListTile(
                      leading: const Icon(Icons.train, size: 40),
                      title: Text(
                        _result!.nearestStation!.station,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(_result!.nearestStation!.line),
                      trailing: Chip(
                        label: Text(_result!.nearestStation!.lcsCode),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    ),
                    const Divider(),
                  ],
                  if (_result!.nearestSection != null) ...[
                    ListTile(
                      leading: const Icon(Icons.railway_alert),
                      title: const Text('Track Section'),
                      subtitle: Text(_result!.nearestSection!.trackSection),
                      trailing: Text('Track ${_result!.nearestSection!.track}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed),
                      title: const Text('Meterage Range'),
                      subtitle: Text(
                        '${_result!.nearestSection!.lcsMeterageStart.toStringAsFixed(2)} - '
                        '${_result!.nearestSection!.lcsMeterageEnd.toStringAsFixed(2)} m',
                      ),
                    ),
                    if (_result!.distanceToNearestStation > 0)
                      ListTile(
                        leading: const Icon(Icons.near_me),
                        title: const Text('Distance to Station'),
                        subtitle: Text(
                          '${_result!.distanceToNearestStation.toStringAsFixed(2)} meters',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Nearby stations
          if (_result!.nearbyStations.isNotEmpty) ...[
            const Text(
              'Nearby Stations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _result!.nearbyStations.length,
                itemBuilder: (context, index) {
                  final station = _result!.nearbyStations[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.station,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              station.line,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),
                            Chip(
                              label: Text(station.lcsCode),
                              backgroundColor: Colors.green.shade100,
                              labelStyle: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Network connections
          if (_result!.nearestStation != null) ...[
            ElevatedButton(
              onPressed: () {
                final connections = EnhancedDataService()
                    .getNetworkConnections(_result!.nearestStation!.lcsCode);
                _showConnectionsDialog(connections);
              },
              child: const Text('View Network Connections'),
            ),
          ],

          const SizedBox(height: 20),

          // Export and share buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Export functionality
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Results'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Share functionality
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConnectionsDialog(Map<String, dynamic> connections) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${connections['station']} Connections'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text('Primary Line: ${connections['primary_line']}'),
              ),
              ListTile(
                title: Text('LCS Code: ${connections['lcs_code']}'),
              ),
              ListTile(
                title: Text('Track Sections: ${connections['sections_count']}'),
              ),
              const Divider(),
              if (connections['connections'] != null)
                ...(connections['connections'] as Map<String, List<String>>)
                    .entries
                    .map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...entry.value.map((station) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('• $station'),
                                )),
                          ],
                        ))
                    .toList(),
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
}