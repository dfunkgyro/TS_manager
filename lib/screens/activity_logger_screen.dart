import 'package:flutter/material.dart';
import 'package:track_sections_manager/services/activity_logger.dart';
import 'dart:async';

/// Activity Logger Viewer Screen - Real-time log monitoring
class ActivityLoggerScreen extends StatefulWidget {
  const ActivityLoggerScreen({super.key});

  @override
  State<ActivityLoggerScreen> createState() => _ActivityLoggerScreenState();
}

class _ActivityLoggerScreenState extends State<ActivityLoggerScreen> {
  final ActivityLogger _logger = ActivityLogger();
  List<LogEntry> _displayedLogs = [];
  LogLevel? _filterLevel;
  String? _filterCategory;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  final Set<String> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadLogs();

    // Add listener for real-time updates
    _logger.addListener(_onNewLog);

    // Auto-refresh every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadLogs();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _logger.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog(LogEntry entry) {
    if (mounted) {
      setState(() {
        _loadLogs();
        if (_autoScroll && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _loadLogs() {
    var logs = _logger.getAllLogs();

    // Apply filters
    if (_filterLevel != null) {
      logs = logs.where((log) => log.level == _filterLevel).toList();
    }
    if (_filterCategory != null) {
      logs = logs.where((log) => log.category == _filterCategory).toList();
    }

    // Build category set
    _categories.clear();
    for (final log in _logger.getAllLogs()) {
      _categories.add(log.category);
    }

    setState(() {
      _displayedLogs = logs;
    });
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.success:
        return Colors.green;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.success:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logger'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.lock_clock : Icons.lock_open),
            tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh logs',
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export logs',
            onPressed: _exportLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Filter by Level:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    _buildLevelChip(null, 'All'),
                    _buildLevelChip(LogLevel.debug, 'Debug'),
                    _buildLevelChip(LogLevel.info, 'Info'),
                    _buildLevelChip(LogLevel.warning, 'Warning'),
                    _buildLevelChip(LogLevel.error, 'Error'),
                    _buildLevelChip(LogLevel.success, 'Success'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    _buildCategoryChip(null, 'All'),
                    ..._categories.map((cat) => _buildCategoryChip(cat, cat)),
                  ],
                ),
              ],
            ),
          ),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Text('Total Logs: ${_displayedLogs.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 20),
                Text('Errors: ${_logger.getLogsByLevel(LogLevel.error).length}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(width: 20),
                Text('Warnings: ${_logger.getLogsByLevel(LogLevel.warning).length}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Logs list
          Expanded(
            child: _displayedLogs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No logs to display', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _displayedLogs.length,
                    itemBuilder: (context, index) {
                      final log = _displayedLogs[index];
                      return _buildLogEntry(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(LogLevel? level, String label) {
    final isSelected = _filterLevel == level;
    final color = level != null ? _getLevelColor(level) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withOpacity(0.3),
        checkmarkColor: color,
        onSelected: (selected) {
          setState(() {
            _filterLevel = selected ? level : null;
            _loadLogs();
          });
        },
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _filterCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.blue.withOpacity(0.3),
        onSelected: (selected) {
          setState(() {
            _filterCategory = selected ? category : null;
            _loadLogs();
          });
        },
      ),
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    final color = _getLevelColor(log.level);
    final icon = _getLevelIcon(log.level);
    final time = log.timestamp.toString().substring(11, 19);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.category,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.message,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Full Message:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  log.message,
                  style: const TextStyle(fontSize: 14),
                ),
                if (log.data != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Additional Data:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      log.data.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Timestamp: ${log.timestamp}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportLogs() {
    final jsonLogs = _logger.exportLogsAsJson();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Logs'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonLogs,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Copy to clipboard functionality would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs exported to console'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy JSON'),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will permanently delete all logs. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.clear();
              _loadLogs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All logs cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
