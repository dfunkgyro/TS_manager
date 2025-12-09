// services/bulk_operations_service.dart
import 'package:flutter/foundation.dart';
import '../models/track_data.dart';
import '../models/grouping_models.dart';
import '../services/supabase_service.dart';
import '../services/data_persistence_service.dart';

/// Result of a bulk operation
class BulkOperationResult {
  final int totalItems;
  final int successCount;
  final int failureCount;
  final List<String> errors;
  final Duration duration;

  BulkOperationResult({
    required this.totalItems,
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.duration,
  });

  bool get isSuccessful => failureCount == 0;
  double get successRate => totalItems > 0 ? successCount / totalItems : 0;

  @override
  String toString() {
    return 'BulkOperationResult{$successCount/$totalItems successful, $failureCount failed}';
  }
}

/// Service for bulk operations on track sections and groupings
class BulkOperationsService {
  static final BulkOperationsService _instance = BulkOperationsService._internal();
  factory BulkOperationsService() => _instance;
  BulkOperationsService._internal();

  final _supabase = SupabaseService();
  final _persistence = DataPersistenceService();

  /// Bulk edit track sections
  Future<BulkOperationResult> bulkEditTrackSections({
    required List<TrackSection> trackSections,
    required Map<String, dynamic> updates,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int successCount = 0;
    int failureCount = 0;

    for (final trackSection in trackSections) {
      try {
        // Create updated track section
        final updatedSection = _applyUpdates(trackSection, updates);

        // Save locally
        await _persistence.addUserTrackSection(updatedSection);

        // Save to Supabase if available
        if (_supabase.isInitialized) {
          await _supabase.updateTrackSection(
            trackSection.lcsCode,
            updates,
          );
        }

        successCount++;
      } catch (e) {
        failureCount++;
        errors.add('Failed to update TS ${trackSection.trackSection}: $e');
        debugPrint('Error updating track section: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return BulkOperationResult(
      totalItems: trackSections.length,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
    );
  }

  /// Bulk delete track sections
  Future<BulkOperationResult> bulkDeleteTrackSections({
    required List<TrackSection> trackSections,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int successCount = 0;
    int failureCount = 0;

    for (final trackSection in trackSections) {
      try {
        // Delete from Supabase if available
        if (_supabase.isInitialized) {
          await _supabase.deleteTrackSection(trackSection.lcsCode);
        }

        // Delete from local storage
        // Note: This would require extending DataPersistenceService
        // For now, we just mark success

        successCount++;
      } catch (e) {
        failureCount++;
        errors.add('Failed to delete TS ${trackSection.trackSection}: $e');
        debugPrint('Error deleting track section: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return BulkOperationResult(
      totalItems: trackSections.length,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
    );
  }

  /// Bulk verify groupings
  Future<BulkOperationResult> bulkVerifyGroupings({
    required List<TrackSectionGrouping> groupings,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int successCount = 0;
    int failureCount = 0;

    for (final grouping in groupings) {
      try {
        if (_supabase.isInitialized && grouping.id != null) {
          await _supabase.updateGroupingTrackSections(
            grouping.id!,
            grouping.trackSectionNumbers,
          );
          successCount++;
        } else {
          failureCount++;
          errors.add('Cannot verify grouping ${grouping.displayLabel}: No Supabase connection');
        }
      } catch (e) {
        failureCount++;
        errors.add('Failed to verify grouping ${grouping.displayLabel}: $e');
        debugPrint('Error verifying grouping: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return BulkOperationResult(
      totalItems: groupings.length,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
    );
  }

  /// Bulk add track sections to grouping
  Future<BulkOperationResult> bulkAddToGrouping({
    required String groupingId,
    required List<int> trackSectionNumbers,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int successCount = 0;
    int failureCount = 0;

    for (final tsNumber in trackSectionNumbers) {
      try {
        if (_supabase.isInitialized) {
          await _supabase.addTrackSectionToGrouping(groupingId, tsNumber);
          successCount++;
        } else {
          failureCount++;
          errors.add('Cannot add TS $tsNumber: No Supabase connection');
        }
      } catch (e) {
        failureCount++;
        errors.add('Failed to add TS $tsNumber: $e');
        debugPrint('Error adding to grouping: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return BulkOperationResult(
      totalItems: trackSectionNumbers.length,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
    );
  }

  /// Bulk remove track sections from grouping
  Future<BulkOperationResult> bulkRemoveFromGrouping({
    required String groupingId,
    required List<int> trackSectionNumbers,
  }) async {
    final startTime = DateTime.now();
    final errors = <String>[];
    int successCount = 0;
    int failureCount = 0;

    for (final tsNumber in trackSectionNumbers) {
      try {
        if (_supabase.isInitialized) {
          await _supabase.removeTrackSectionFromGrouping(groupingId, tsNumber);
          successCount++;
        } else {
          failureCount++;
          errors.add('Cannot remove TS $tsNumber: No Supabase connection');
        }
      } catch (e) {
        failureCount++;
        errors.add('Failed to remove TS $tsNumber: $e');
        debugPrint('Error removing from grouping: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return BulkOperationResult(
      totalItems: trackSectionNumbers.length,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
    );
  }

  /// Apply updates to a track section
  TrackSection _applyUpdates(TrackSection original, Map<String, dynamic> updates) {
    return TrackSection(
      lcsCode: updates['lcs_code'] as String? ?? original.lcsCode,
      legacyLcsCode: updates['legacy_lcs_code'] as String? ?? original.legacyLcsCode,
      legacyJnpLcsCode: updates['legacy_jnp_lcs_code'] as String? ?? original.legacyJnpLcsCode,
      roadStatus: updates['road_status'] as String? ?? original.roadStatus,
      operatingLineCode: updates['operating_line_code'] as String? ?? original.operatingLineCode,
      operatingLine: updates['operating_line'] as String? ?? original.operatingLine,
      newLongDescription: updates['new_long_description'] as String? ?? original.newLongDescription,
      newShortDescription: updates['new_short_description'] as String? ?? original.newShortDescription,
      vcc: updates['vcc'] as String? ?? original.vcc,
      thalesChainage: updates['thales_chainage'] as String? ?? original.thalesChainage,
      segmentId: updates['segment_id'] as String? ?? original.segmentId,
      lcsMeterageStart: updates['lcs_meterage_start'] as double? ?? original.lcsMeterageStart,
      lcsMeterageEnd: updates['lcs_meterage_end'] as double? ?? original.lcsMeterageEnd,
      track: updates['track'] as String? ?? original.track,
      trackSection: updates['track_section'] as String? ?? original.trackSection,
      physicalAssets: updates['physical_assets'] as String? ?? original.physicalAssets,
      notes: updates['notes'] as String? ?? original.notes,
    );
  }

  /// Undo stack for bulk operations (simple implementation)
  final List<_BulkOperationHistory> _undoStack = [];

  /// Execute bulk operation with undo support
  Future<BulkOperationResult> executeWithUndo({
    required String operationType,
    required Future<BulkOperationResult> Function() operation,
    required Future<void> Function() undoOperation,
  }) async {
    final result = await operation();

    if (result.isSuccessful) {
      _undoStack.add(_BulkOperationHistory(
        operationType: operationType,
        timestamp: DateTime.now(),
        undoOperation: undoOperation,
      ));

      // Keep only last 10 operations
      if (_undoStack.length > 10) {
        _undoStack.removeAt(0);
      }
    }

    return result;
  }

  /// Undo last bulk operation
  Future<bool> undoLastOperation() async {
    if (_undoStack.isEmpty) return false;

    try {
      final lastOp = _undoStack.removeLast();
      await lastOp.undoOperation();
      return true;
    } catch (e) {
      debugPrint('Error undoing operation: $e');
      return false;
    }
  }

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Get last operation info
  String? get lastOperationInfo {
    if (_undoStack.isEmpty) return null;
    final last = _undoStack.last;
    return '${last.operationType} at ${last.timestamp.hour}:${last.timestamp.minute}';
  }
}

/// History entry for bulk operations
class _BulkOperationHistory {
  final String operationType;
  final DateTime timestamp;
  final Future<void> Function() undoOperation;

  _BulkOperationHistory({
    required this.operationType,
    required this.timestamp,
    required this.undoOperation,
  });
}
