// models/tsr_models.dart

/// Represents a Temporary Speed Restriction (TSR)
class TemporarySpeedRestriction {
  final String? id;
  final String tsrNumber;
  final String? tsrName;

  // Location
  final String lcsCode;
  final double startMeterage;
  final double endMeterage;

  // Operating details
  final String operatingLine;
  final String? roadDirection;

  // Speed information
  final int? normalSpeedMph;
  final int restrictedSpeedMph;

  // Dates & status
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final String status; // 'planned', 'active', 'ended', 'cancelled'

  // Reason & details
  final String reason; // 'construction', 'inspection', 'maintenance', 'emergency'
  final String? description;

  // Contact & authority
  final String? requestedBy;
  final String? approvedBy;
  final String? contactInfo;

  // Associated track sections
  final List<int> affectedTrackSections;

  // Metadata
  final String? notes;
  final Map<String, dynamic>? attachments;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  TemporarySpeedRestriction({
    this.id,
    required this.tsrNumber,
    this.tsrName,
    required this.lcsCode,
    required this.startMeterage,
    required this.endMeterage,
    required this.operatingLine,
    this.roadDirection,
    this.normalSpeedMph,
    required this.restrictedSpeedMph,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.status = 'planned',
    required this.reason,
    this.description,
    this.requestedBy,
    this.approvedBy,
    this.contactInfo,
    this.affectedTrackSections = const [],
    this.notes,
    this.attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from JSON
  factory TemporarySpeedRestriction.fromJson(Map<String, dynamic> json) {
    return TemporarySpeedRestriction(
      id: json['id'] as String?,
      tsrNumber: json['tsr_number'] as String,
      tsrName: json['tsr_name'] as String?,
      lcsCode: json['lcs_code'] as String,
      startMeterage: (json['start_meterage'] as num).toDouble(),
      endMeterage: (json['end_meterage'] as num).toDouble(),
      operatingLine: json['operating_line'] as String,
      roadDirection: json['road_direction'] as String?,
      normalSpeedMph: json['normal_speed_mph'] as int?,
      restrictedSpeedMph: json['restricted_speed_mph'] as int,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveUntil: json['effective_until'] != null
          ? DateTime.parse(json['effective_until'] as String)
          : null,
      status: json['status'] as String? ?? 'planned',
      reason: json['reason'] as String,
      description: json['description'] as String?,
      requestedBy: json['requested_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      contactInfo: json['contact_info'] as String?,
      affectedTrackSections: (json['affected_track_sections'] as List?)?.cast<int>() ?? [],
      notes: json['notes'] as String?,
      attachments: json['attachments'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tsr_number': tsrNumber,
      'tsr_name': tsrName,
      'lcs_code': lcsCode,
      'start_meterage': startMeterage,
      'end_meterage': endMeterage,
      'operating_line': operatingLine,
      'road_direction': roadDirection,
      'normal_speed_mph': normalSpeedMph,
      'restricted_speed_mph': restrictedSpeedMph,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_until': effectiveUntil?.toIso8601String(),
      'status': status,
      'reason': reason,
      'description': description,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'contact_info': contactInfo,
      'affected_track_sections': affectedTrackSections,
      'notes': notes,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get meterage range
  double get meterageRange => endMeterage - startMeterage;

  /// Check if TSR is currently active
  bool get isActive {
    if (status != 'active') return false;
    final now = DateTime.now();
    if (now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) return false;
    return true;
  }

  /// Check if TSR is planned
  bool get isPlanned => status == 'planned';

  /// Check if TSR has ended
  bool get hasEnded => status == 'ended' || (effectiveUntil != null && DateTime.now().isAfter(effectiveUntil!));

  /// Get speed reduction percentage
  double? get speedReductionPercentage {
    if (normalSpeedMph == null) return null;
    return ((normalSpeedMph! - restrictedSpeedMph) / normalSpeedMph!) * 100;
  }

  /// Get display name
  String get displayName => tsrName ?? 'TSR $tsrNumber';

  /// Get status color (for UI)
  String get statusColor {
    switch (status) {
      case 'active':
        return '#FF0000'; // Red
      case 'planned':
        return '#FFA500'; // Orange
      case 'ended':
        return '#808080'; // Gray
      case 'cancelled':
        return '#000000'; // Black
      default:
        return '#808080';
    }
  }

  /// Copy with modifications
  TemporarySpeedRestriction copyWith({
    String? status,
    DateTime? effectiveUntil,
    List<int>? affectedTrackSections,
    String? notes,
  }) {
    return TemporarySpeedRestriction(
      id: id,
      tsrNumber: tsrNumber,
      tsrName: tsrName,
      lcsCode: lcsCode,
      startMeterage: startMeterage,
      endMeterage: endMeterage,
      operatingLine: operatingLine,
      roadDirection: roadDirection,
      normalSpeedMph: normalSpeedMph,
      restrictedSpeedMph: restrictedSpeedMph,
      effectiveFrom: effectiveFrom,
      effectiveUntil: effectiveUntil ?? this.effectiveUntil,
      status: status ?? this.status,
      reason: reason,
      description: description,
      requestedBy: requestedBy,
      approvedBy: approvedBy,
      contactInfo: contactInfo,
      affectedTrackSections: affectedTrackSections ?? this.affectedTrackSections,
      notes: notes ?? this.notes,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TSR{$tsrNumber: $lcsCode @ ${startMeterage}m-${endMeterage}m, $restrictedSpeedMph mph, $status}';
  }
}

/// Reason categories for TSR
class TSRReason {
  static const String construction = 'construction';
  static const String inspection = 'inspection';
  static const String maintenance = 'maintenance';
  static const String emergency = 'emergency';
  static const String testing = 'testing';
  static const String weather = 'weather';
  static const String other = 'other';

  static List<String> get all => [
        construction,
        inspection,
        maintenance,
        emergency,
        testing,
        weather,
        other,
      ];

  static String getDisplayName(String reason) {
    switch (reason) {
      case construction:
        return 'Construction Work';
      case inspection:
        return 'Track Inspection';
      case maintenance:
        return 'Maintenance';
      case emergency:
        return 'Emergency';
      case testing:
        return 'Testing';
      case weather:
        return 'Weather Conditions';
      case other:
        return 'Other';
      default:
        return reason;
    }
  }
}

/// Status categories for TSR
class TSRStatus {
  static const String planned = 'planned';
  static const String active = 'active';
  static const String ended = 'ended';
  static const String cancelled = 'cancelled';

  static List<String> get all => [planned, active, ended, cancelled];

  static String getDisplayName(String status) {
    switch (status) {
      case planned:
        return 'Planned';
      case active:
        return 'Active';
      case ended:
        return 'Ended';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}
