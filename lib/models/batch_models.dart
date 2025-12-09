// models/batch_models.dart
import 'package:flutter/foundation.dart';

/// Represents a batch operation for creating multiple track sections
class BatchOperation {
  final String? id;
  final String operationType;
  final String status; // 'pending', 'processing', 'completed', 'failed', 'partial'

  // Input parameters
  final int startTrackSection;
  final int endTrackSection;
  final double startChainage;
  final double endChainage;

  // Shared parameters
  final String lcsCode;
  final String? station;
  final String operatingLine;
  final String roadDirection;
  final String? vcc;

  // Results
  final int totalItems;
  final int successfulItems;
  final int failedItems;
  final int conflictedItems;

  // Conflict resolution
  final String? conflictResolution; // 'keep_existing', 'replace_all', 'skip_conflicts'
  final Map<String, dynamic>? conflictsData;

  // Metadata
  final String? userId;
  final String? notes;
  final String? errorLog;

  // Timestamps
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  BatchOperation({
    this.id,
    required this.operationType,
    required this.status,
    required this.startTrackSection,
    required this.endTrackSection,
    required this.startChainage,
    required this.endChainage,
    required this.lcsCode,
    this.station,
    required this.operatingLine,
    required this.roadDirection,
    this.vcc,
    this.totalItems = 0,
    this.successfulItems = 0,
    this.failedItems = 0,
    this.conflictedItems = 0,
    this.conflictResolution,
    this.conflictsData,
    this.userId,
    this.notes,
    this.errorLog,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from JSON
  factory BatchOperation.fromJson(Map<String, dynamic> json) {
    return BatchOperation(
      id: json['id'] as String?,
      operationType: json['operation_type'] as String,
      status: json['status'] as String,
      startTrackSection: json['start_track_section'] as int,
      endTrackSection: json['end_track_section'] as int,
      startChainage: (json['start_chainage'] as num).toDouble(),
      endChainage: (json['end_chainage'] as num).toDouble(),
      lcsCode: json['lcs_code'] as String,
      station: json['station'] as String?,
      operatingLine: json['operating_line'] as String,
      roadDirection: json['road_direction'] as String,
      vcc: json['vcc'] as String?,
      totalItems: json['total_items'] as int? ?? 0,
      successfulItems: json['successful_items'] as int? ?? 0,
      failedItems: json['failed_items'] as int? ?? 0,
      conflictedItems: json['conflicted_items'] as int? ?? 0,
      conflictResolution: json['conflict_resolution'] as String?,
      conflictsData: json['conflicts_data'] as Map<String, dynamic>?,
      userId: json['user_id'] as String?,
      notes: json['notes'] as String?,
      errorLog: json['error_log'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'operation_type': operationType,
      'status': status,
      'start_track_section': startTrackSection,
      'end_track_section': endTrackSection,
      'start_chainage': startChainage,
      'end_chainage': endChainage,
      'lcs_code': lcsCode,
      'station': station,
      'operating_line': operatingLine,
      'road_direction': roadDirection,
      'vcc': vcc,
      'total_items': totalItems,
      'successful_items': successfulItems,
      'failed_items': failedItems,
      'conflicted_items': conflictedItems,
      'conflict_resolution': conflictResolution,
      'conflicts_data': conflictsData,
      'user_id': userId,
      'notes': notes,
      'error_log': errorLog,
      'created_at': createdAt.toIso8601String(),
      if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  /// Copy with modifications
  BatchOperation copyWith({
    String? status,
    int? totalItems,
    int? successfulItems,
    int? failedItems,
    int? conflictedItems,
    String? conflictResolution,
    Map<String, dynamic>? conflictsData,
    String? errorLog,
    DateTime? completedAt,
  }) {
    return BatchOperation(
      id: id,
      operationType: operationType,
      status: status ?? this.status,
      startTrackSection: startTrackSection,
      endTrackSection: endTrackSection,
      startChainage: startChainage,
      endChainage: endChainage,
      lcsCode: lcsCode,
      station: station,
      operatingLine: operatingLine,
      roadDirection: roadDirection,
      vcc: vcc,
      totalItems: totalItems ?? this.totalItems,
      successfulItems: successfulItems ?? this.successfulItems,
      failedItems: failedItems ?? this.failedItems,
      conflictedItems: conflictedItems ?? this.conflictedItems,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      conflictsData: conflictsData ?? this.conflictsData,
      userId: userId,
      notes: notes,
      errorLog: errorLog ?? this.errorLog,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Check if operation is complete
  bool get isComplete => status == 'completed' || status == 'failed' || status == 'partial';

  /// Check if operation was successful
  bool get isSuccessful => status == 'completed';

  /// Get progress percentage
  double get progressPercentage {
    if (totalItems == 0) return 0;
    return ((successfulItems + failedItems + conflictedItems) / totalItems) * 100;
  }

  /// Get summary string
  String get summary {
    if (isComplete) {
      return '$successfulItems successful, $failedItems failed, $conflictedItems conflicts out of $totalItems items';
    }
    return 'Processing $totalItems items...';
  }

  @override
  String toString() {
    return 'BatchOperation{id: $id, status: $status, $summary}';
  }
}

/// Represents a single item in a batch operation
class BatchOperationItem {
  final String? id;
  final String batchOperationId;

  // Item details
  final int trackSectionNumber;
  final double chainage;
  final double lcsMeterage;

  // Status
  final String status; // 'pending', 'inserted', 'skipped', 'failed', 'conflict'
  final String? conflictType; // 'duplicate_number', 'chainage_overlap'
  final Map<String, dynamic>? existingData;

  // Error details
  final String? errorMessage;

  // Timestamps
  final DateTime createdAt;
  final DateTime? processedAt;

  BatchOperationItem({
    this.id,
    required this.batchOperationId,
    required this.trackSectionNumber,
    required this.chainage,
    required this.lcsMeterage,
    this.status = 'pending',
    this.conflictType,
    this.existingData,
    this.errorMessage,
    DateTime? createdAt,
    this.processedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from JSON
  factory BatchOperationItem.fromJson(Map<String, dynamic> json) {
    return BatchOperationItem(
      id: json['id'] as String?,
      batchOperationId: json['batch_operation_id'] as String,
      trackSectionNumber: json['track_section_number'] as int,
      chainage: (json['chainage'] as num).toDouble(),
      lcsMeterage: (json['lcs_meterage'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      conflictType: json['conflict_type'] as String?,
      existingData: json['existing_data'] as Map<String, dynamic>?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at'] as String) : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'batch_operation_id': batchOperationId,
      'track_section_number': trackSectionNumber,
      'chainage': chainage,
      'lcs_meterage': lcsMeterage,
      'status': status,
      'conflict_type': conflictType,
      'existing_data': existingData,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
    };
  }

  /// Check if item has conflict
  bool get hasConflict => status == 'conflict';

  /// Check if item was successful
  bool get isSuccessful => status == 'inserted';

  @override
  String toString() {
    return 'BatchOperationItem{trackSection: $trackSectionNumber, status: $status}';
  }
}

/// Represents conflict information for review
class ConflictInfo {
  final int trackSectionNumber;
  final double proposedChainage;
  final double proposedMeterage;

  // Existing data
  final double existingChainage;
  final double existingMeterage;
  final String? existingLcsCode;
  final String? existingStation;

  // Metadata
  final String conflictType;
  final String? notes;

  ConflictInfo({
    required this.trackSectionNumber,
    required this.proposedChainage,
    required this.proposedMeterage,
    required this.existingChainage,
    required this.existingMeterage,
    this.existingLcsCode,
    this.existingStation,
    required this.conflictType,
    this.notes,
  });

  /// Get difference in chainage
  double get chainageDifference => (proposedChainage - existingChainage).abs();

  /// Get difference in meterage
  double get meterageDifference => (proposedMeterage - existingMeterage).abs();

  /// Check if conflict is significant
  bool get isSignificant => chainageDifference > 10 || meterageDifference > 10;

  /// Create from existing track section data
  factory ConflictInfo.fromExisting({
    required int trackSectionNumber,
    required double proposedChainage,
    required double proposedMeterage,
    required Map<String, dynamic> existingData,
  }) {
    return ConflictInfo(
      trackSectionNumber: trackSectionNumber,
      proposedChainage: proposedChainage,
      proposedMeterage: proposedMeterage,
      existingChainage: (existingData['thales_chainage'] as num?)?.toDouble() ?? 0,
      existingMeterage: (existingData['lcs_meterage'] as num?)?.toDouble() ?? 0,
      existingLcsCode: existingData['lcs_code'] as String?,
      existingStation: existingData['station'] as String?,
      conflictType: 'duplicate_number',
    );
  }

  @override
  String toString() {
    return 'ConflictInfo{TS$trackSectionNumber: proposed=${proposedChainage}m vs existing=${existingChainage}m}';
  }
}
