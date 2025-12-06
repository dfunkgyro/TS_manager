// screens/query_screen.dart
import 'package:flutter/material.dart';
import 'package:track_sections_manager/models/track_data.dart';
import 'package:track_sections_manager/models/enhanced_track_data.dart';
import 'package:track_sections_manager/services/data_service.dart';
import 'package:track_sections_manager/services/enhanced_data_service.dart';
import 'package:track_sections_manager/widgets/result_card.dart';
import 'package:track_sections_manager/widgets/station_card.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _meterageController = TextEditingController();
  final TextEditingController _lcsController = TextEditingController();
  final TextEditingController _stationSearchController = TextEditingController();

  QueryResult? _result;
  EnhancedQueryResult? _enhancedResult;
  List<LCSStationMapping> _stationResults = [];
  bool _isLoading = false;
  String _activeSearchType = 'meterage';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeSearchType = ['meterage', 'lcs', 'station'][_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _meterageController.dispose();
    _lcsController.dispose();
    _stationSearchController.dispose();
    super.dispose();
  }

  void _searchByMeterage() {
    final meterage = double.tryParse(_meterageController.text);
    if (meterage == null) {
      _showError('Please enter a valid meterage value');
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final result = DataService().searchByMeterage(meterage);
      final enhancedResult = EnhancedDataService().enhancedSearchByMeterage(meterage);

      setState(() {
        _result = result;
        _enhancedResult = enhancedResult;
        _isLoading = false;
      });
    });
  }

  void _searchByLcs() {
    final lcsCode = _lcsController.text.trim();
    if (lcsCode.isEmpty) {
      _showError('Please enter an LCS Code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      Future.delayed(const Duration(milliseconds: 500), () {
        final result = DataService().searchByLcsCode(lcsCode);
        final enhancedResult = EnhancedDataService().enhancedSearchByLcsCode(lcsCode);

        setState(() {
          _result = result;
          _enhancedResult = enhancedResult;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _searchStations() {
    final query = _stationSearchController.text.trim();
    if (query.isEmpty) {
      _showError('Please enter a search term');
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      final results = EnhancedDataService().searchStations(query);
      setState(() {
        _stationResults = results;
        _isLoading = false;
      });
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Query'),
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.speed), text: 'Meterage'),
            Tab(icon: Icon(Icons.qr_code), text: 'LCS Code'),
            Tab(icon: Icon(Icons.search), text: 'Station'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMeterageTab(),
          _buildLcsTab(),
          _buildStationTab(),
        ],
      ),
    );
  }

  Widget _buildMeterageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Search by Meterage',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _meterageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Meterage Value',
                      hintText: 'e.g., 15125.5',
                      prefixIcon: const Icon(Icons.speed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _searchByMeterage(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchByMeterage,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null) _buildResults(),
        ],
      ),
    );
  }

  Widget _buildLcsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Search by LCS Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _lcsController,
                    decoration: InputDecoration(
                      labelText: 'LCS Code',
                      hintText: 'e.g., M189 or D011',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _searchByLcs(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchByLcs,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null) _buildResults(),
        ],
      ),
    );
  }

  Widget _buildStationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Search Stations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _stationSearchController,
                    decoration: InputDecoration(
                      labelText: 'Station Name or LCS Code',
                      hintText: 'e.g., Baker Street',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _stationSearchController.clear();
                          setState(() => _stationResults.clear());
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _searchStations(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _searchStations,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_stationResults.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stationResults.length,
              itemBuilder: (context, index) {
                return StationCard(mapping: _stationResults[index]);
              },
            )
          else if (_stationSearchController.text.isNotEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No stations found'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search Results',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (_result != null) ResultCard(result: _result!),
        if (_enhancedResult?.nearbyStations.isNotEmpty ?? false) ...[
          const SizedBox(height: 20),
          const Text(
            'Nearby Stations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _enhancedResult!.nearbyStations.length,
              itemBuilder: (context, index) {
                final station = _enhancedResult!.nearbyStations[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 10),
                  child: Card(
                    elevation: 3,
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting results...')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Export'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sharing results...')),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
