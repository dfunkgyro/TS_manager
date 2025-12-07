import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Activity Logger for debugging and monitoring app behavior
class ActivityLogger {
  static ActivityLogger? _instance;
  final Queue<LogEntry> _logs = Queue();
  static const int _maxLogs = 500;

  // Log listeners for real-time updates
  final List<Function(LogEntry)> _listeners = [];

  ActivityLogger._();

  factory ActivityLogger() {
    _instance ??= ActivityLogger._();
    return _instance!;
  }

  /// Add a log entry
  void log(String message, {LogLevel level = LogLevel.info, String? category, Map<String, dynamic>? data}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category ?? 'General',
      data: data,
    );

    _logs.add(entry);

    // Keep only last N logs
    while (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // Print to console in debug mode
    if (kDebugMode) {
      final icon = _getLogIcon(level);
      final time = entry.timestamp.toString().substring(11, 19);
      debugPrint('[$time] $icon [${entry.category}] ${entry.message}');
      if (data != null) {
        debugPrint('  Data: $data');
      }
    }

    // Notify listeners
    for (final listener in _listeners) {
      listener(entry);
    }

    // Save important logs
    if (level == LogLevel.error || level == LogLevel.warning) {
      _saveToPersistence();
    }
  }

  String _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  /// Add a listener for log updates
  void addListener(Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  /// Get all logs
  List<LogEntry> getAllLogs() => _logs.toList();

  /// Get logs by category
  List<LogEntry> getLogsByCategory(String category) {
    return _logs.where((log) => log.category == category).toList();
  }

  /// Get logs by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Export logs as JSON
  String exportLogsAsJson() {
    final logsData = _logs.map((log) => log.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exported_at': DateTime.now().toIso8601String(),
      'total_logs': logsData.length,
      'logs': logsData,
    });
  }

  /// Save critical logs to persistence
  Future<void> _saveToPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final criticalLogs = _logs
          .where((log) => log.level == LogLevel.error || log.level == LogLevel.warning)
          .take(100)
          .map((log) => log.toJson())
          .toList();

      await prefs.setString('critical_logs', jsonEncode(criticalLogs));
    } catch (e) {
      debugPrint('Failed to save logs: $e');
    }
  }

  /// Load saved logs
  Future<void> loadSavedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogs = prefs.getString('critical_logs');

      if (savedLogs != null) {
        final List<dynamic> logsData = jsonDecode(savedLogs);
        for (final logData in logsData) {
          final entry = LogEntry.fromJson(logData);
          _logs.add(entry);
        }
        log('Loaded ${logsData.length} saved logs', category: 'Logger');
      }
    } catch (e) {
      debugPrint('Failed to load saved logs: $e');
    }
  }
}

/// Log entry model
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String category;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.category,
    this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString().split('.').last,
      'message': message,
      'category': category,
      if (data != null) 'data': data,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere(
        (l) => l.toString().split('.').last == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'],
      category: json['category'],
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    final time = timestamp.toString().substring(11, 19);
    return '[$time] [${level.toString().split('.').last.toUpperCase()}] [$category] $message';
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
}
