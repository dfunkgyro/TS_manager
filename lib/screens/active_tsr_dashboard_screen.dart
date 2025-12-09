// screens/active_tsr_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/tsr_models.dart';
import '../services/supabase_service.dart';
import 'tsr_creation_wizard_screen.dart';

/// Dashboard showing all active TSRs
class ActiveTSRDashboardScreen extends StatefulWidget {
  const ActiveTSRDashboardScreen({super.key});

  @override
  State<ActiveTSRDashboardScreen> createState() => _ActiveTSRDashboardScreenState();
}

class _ActiveTSRDashboardScreenState extends State<ActiveTSRDashboardScreen> {
  final _supabase = SupabaseService();

  List<TemporarySpeedRestriction> _allTSRs = [];
  List<TemporarySpeedRestriction> _filteredTSRs = [];
  bool _isLoading = false;
  String? _selectedLine;
  String? _selectedStatus;
  int? _maxSpeed;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTSRs();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadTSRs());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTSRs() async {
    if (!_supabase.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase not configured. Running in offline mode.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Load all active TSRs
      final activeTSRs = await _supabase.getActiveTSRs();

      // Also load planned TSRs
      final allTSRsData = await _supabase.client
          .from('temporary_speed_restrictions')
          .select()
          .order('effective_from', ascending: false);

      final tsrs = (allTSRsData as List)
          .map((data) => TemporarySpeedRestriction.fromJson(data))
          .toList();

      setState(() {
        _allTSRs = tsrs;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading TSRs: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var filtered = _allTSRs;

    if (_selectedLine != null) {
      filtered = filtered.where((tsr) => tsr.operatingLine == _selectedLine).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered.where((tsr) => tsr.status == _selectedStatus).toList();
    }

    if (_maxSpeed != null) {
      filtered = filtered.where((tsr) => tsr.restrictedSpeedMph <= _maxSpeed!).toList();
    }

    setState(() {
      _filteredTSRs = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active TSR Dashboard'),
        backgroundColor: Colors.red.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTSRs,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TSRCreationWizardScreen(),
            ),
          );

          if (result == true) {
            _loadTSRs();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create TSR'),
        backgroundColor: Colors.red.shade700,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTSRs,
        child: _isLoading && _allTSRs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard(),
      ),
    );
  }

  Widget _buildDashboard() {
    if (_filteredTSRs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _allTSRs.isEmpty ? 'No TSRs Found' : 'No TSRs Match Filters',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _allTSRs.isEmpty
                  ? 'Create your first TSR using the + button'
                  : 'Adjust filters to see more TSRs',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final activeTSRs = _filteredTSRs.where((tsr) => tsr.status == 'active').toList();
    final plannedTSRs = _filteredTSRs.where((tsr) => tsr.status == 'planned').toList();
    final endedTSRs = _filteredTSRs.where((tsr) => tsr.status == 'ended').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsCards(),
        const SizedBox(height: 20),
        if (_selectedLine != null || _selectedStatus != null || _maxSpeed != null)
          _buildActiveFilters(),
        if (activeTSRs.isNotEmpty) ...[
          _buildSectionHeader('Active TSRs', activeTSRs.length, Colors.red),
          ...activeTSRs.map((tsr) => _buildTSRCard(tsr)),
          const SizedBox(height: 20),
        ],
        if (plannedTSRs.isNotEmpty) ...[
          _buildSectionHeader('Planned TSRs', plannedTSRs.length, Colors.orange),
          ...plannedTSRs.map((tsr) => _buildTSRCard(tsr)),
          const SizedBox(height: 20),
        ],
        if (endedTSRs.isNotEmpty) ...[
          _buildSectionHeader('Ended TSRs', endedTSRs.length, Colors.grey),
          ...endedTSRs.map((tsr) => _buildTSRCard(tsr)),
        ],
      ],
    );
  }

  Widget _buildStatsCards() {
    final active = _filteredTSRs.where((tsr) => tsr.status == 'active').length;
    final planned = _filteredTSRs.where((tsr) => tsr.status == 'planned').length;
    final avgSpeed = _filteredTSRs.isNotEmpty
        ? _filteredTSRs.map((tsr) => tsr.restrictedSpeedMph).reduce((a, b) => a + b) /
            _filteredTSRs.length
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Active',
            active.toString(),
            Icons.warning,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Planned',
            planned.toString(),
            Icons.schedule,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Avg Speed',
            '${avgSpeed.toStringAsFixed(0)} mph',
            Icons.speed,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_selectedLine != null)
            Chip(
              label: Text('Line: $_selectedLine'),
              onDeleted: () {
                setState(() {
                  _selectedLine = null;
                  _applyFilters();
                });
              },
            ),
          if (_selectedStatus != null)
            Chip(
              label: Text('Status: $_selectedStatus'),
              onDeleted: () {
                setState(() {
                  _selectedStatus = null;
                  _applyFilters();
                });
              },
            ),
          if (_maxSpeed != null)
            Chip(
              label: Text('Speed ≤ $_maxSpeed mph'),
              onDeleted: () {
                setState(() {
                  _maxSpeed = null;
                  _applyFilters();
                });
              },
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedLine = null;
                _selectedStatus = null;
                _maxSpeed = null;
                _applyFilters();
              });
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildTSRCard(TemporarySpeedRestriction tsr) {
    final timeUntilExpiry = tsr.effectiveUntil?.difference(DateTime.now());
    final isExpiringSoon = timeUntilExpiry != null &&
        timeUntilExpiry.inHours < 24 &&
        timeUntilExpiry.inHours > 0;

    Color getSeverityColor() {
      if (tsr.restrictedSpeedMph <= 15) return Colors.red.shade700;
      if (tsr.restrictedSpeedMph <= 30) return Colors.orange.shade700;
      return Colors.yellow.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTSRDetails(tsr),
        borderRadius: BorderRadius.circular(12),
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
                      color: getSeverityColor(),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${tsr.restrictedSpeedMph} mph',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tsr.tsrNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (tsr.tsrName != null)
                          Text(
                            tsr.tsrName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(tsr.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      TSRStatus.getDisplayName(tsr.status),
                      style: TextStyle(
                        color: _getStatusColor(tsr.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${tsr.lcsCode} @ ${tsr.startMeterage.toStringAsFixed(0)}m - ${tsr.endMeterage.toStringAsFixed(0)}m',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.train, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${tsr.operatingLine}${tsr.roadDirection != null ? " ${tsr.roadDirection}" : ""}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'From ${DateFormat('MMM dd, HH:mm').format(tsr.effectiveFrom)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              if (tsr.effectiveUntil != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Until ${DateFormat('MMM dd, HH:mm').format(tsr.effectiveUntil!)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    if (isExpiringSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Expiring in ${timeUntilExpiry.inHours}h',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (tsr.affectedTrackSections.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tsr.affectedTrackSections.take(5).map((tsNumber) {
                    return Chip(
                      label: Text('TS $tsNumber'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList()
                    ..addAll(
                      tsr.affectedTrackSections.length > 5
                        ? [Chip(
                            label: Text('+${tsr.affectedTrackSections.length - 5} more'),
                            visualDensity: VisualDensity.compact,
                          )]
                        : [],
                    ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.red.shade700;
      case 'planned':
        return Colors.orange.shade700;
      case 'ended':
        return Colors.grey.shade600;
      case 'cancelled':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter TSRs'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedLine,
                decoration: const InputDecoration(labelText: 'Operating Line'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Lines')),
                  ...['District Line', 'Circle Line', 'Metropolitan Line', 'Hammersmith & City Line']
                      .map((line) => DropdownMenuItem(value: line, child: Text(line))),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _selectedLine = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Statuses')),
                  ...TSRStatus.all.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(TSRStatus.getDisplayName(status)),
                      )),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _maxSpeed,
                decoration: const InputDecoration(labelText: 'Max Speed'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any Speed')),
                  ...[10, 20, 30, 40, 50].map((speed) => DropdownMenuItem(
                        value: speed,
                        child: Text('≤ $speed mph'),
                      )),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _maxSpeed = value;
                  });
                },
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
            onPressed: () {
              setState(() {
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showTSRDetails(TemporarySpeedRestriction tsr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tsr.tsrNumber,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tsr.tsrName != null)
                              Text(
                                tsr.tsrName!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(tsr.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          TSRStatus.getDisplayName(tsr.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Reason', TSRReason.getDisplayName(tsr.reason)),
                  _buildDetailRow('LCS Code', tsr.lcsCode),
                  _buildDetailRow(
                    'Meterage Range',
                    '${tsr.startMeterage.toStringAsFixed(1)}m - ${tsr.endMeterage.toStringAsFixed(1)}m (${tsr.meterageRange.toStringAsFixed(1)}m)',
                  ),
                  _buildDetailRow('Operating Line', tsr.operatingLine),
                  if (tsr.roadDirection != null)
                    _buildDetailRow('Road Direction', tsr.roadDirection!),
                  _buildDetailRow('Restricted Speed', '${tsr.restrictedSpeedMph} mph'),
                  if (tsr.normalSpeedMph != null)
                    _buildDetailRow('Normal Speed', '${tsr.normalSpeedMph} mph'),
                  _buildDetailRow(
                    'Effective From',
                    DateFormat('EEEE, MMM dd, yyyy HH:mm').format(tsr.effectiveFrom),
                  ),
                  _buildDetailRow(
                    'Effective Until',
                    tsr.effectiveUntil != null
                        ? DateFormat('EEEE, MMM dd, yyyy HH:mm').format(tsr.effectiveUntil!)
                        : 'Indefinite',
                  ),
                  if (tsr.requestedBy != null)
                    _buildDetailRow('Requested By', tsr.requestedBy!),
                  if (tsr.approvedBy != null)
                    _buildDetailRow('Approved By', tsr.approvedBy!),
                  if (tsr.description != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(tsr.description!),
                  ],
                  if (tsr.affectedTrackSections.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Affected Track Sections (${tsr.affectedTrackSections.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tsr.affectedTrackSections.map((tsNumber) {
                        return Chip(label: Text('TS $tsNumber'));
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (tsr.status == 'active' || tsr.status == 'planned')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _endTSR(tsr),
                            icon: const Icon(Icons.stop),
                            label: const Text('End Early'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (tsr.status == 'active')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _extendTSR(tsr),
                            icon: const Icon(Icons.update),
                            label: const Text('Extend'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  Future<void> _endTSR(TemporarySpeedRestriction tsr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End TSR Early'),
        content: Text('Are you sure you want to end TSR ${tsr.tsrNumber} early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End TSR'),
          ),
        ],
      ),
    );

    if (confirm == true && tsr.id != null) {
      final success = await _supabase.updateTSRStatus(tsr.id!, 'ended');
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TSR ended successfully')),
        );
        _loadTSRs();
      }
    }
  }

  Future<void> _extendTSR(TemporarySpeedRestriction tsr) async {
    // TODO: Show dialog to extend TSR
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extend TSR feature coming soon')),
    );
  }
}
