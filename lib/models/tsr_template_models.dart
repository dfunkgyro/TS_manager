// models/tsr_template_models.dart

/// Template for quickly creating TSRs with pre-defined settings
class TSRTemplate {
  final String? id;
  final String name;
  final String description;
  final String reason;
  final int restrictedSpeedMph;
  final int? normalSpeedMph;
  final Duration? defaultDuration;
  final String? defaultStartTime; // e.g., "08:00"
  final String? defaultEndTime; // e.g., "18:00"
  final bool isDefault;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  TSRTemplate({
    this.id,
    required this.name,
    required this.description,
    required this.reason,
    required this.restrictedSpeedMph,
    this.normalSpeedMph,
    this.defaultDuration,
    this.defaultStartTime,
    this.defaultEndTime,
    this.isDefault = false,
    this.usageCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Built-in templates
  static final List<TSRTemplate> builtInTemplates = [
    TSRTemplate(
      id: 'builtin_track_work',
      name: 'Standard Track Work',
      description: '30mph restriction for standard track maintenance during daytime',
      reason: 'construction',
      restrictedSpeedMph: 30,
      normalSpeedMph: 60,
      defaultStartTime: '08:00',
      defaultEndTime: '18:00',
      defaultDuration: const Duration(days: 1),
      isDefault: true,
    ),
    TSRTemplate(
      id: 'builtin_emergency',
      name: 'Emergency Restriction',
      description: '10mph restriction for emergency situations, immediate effect',
      reason: 'emergency',
      restrictedSpeedMph: 10,
      normalSpeedMph: 60,
      isDefault: true,
    ),
    TSRTemplate(
      id: 'builtin_night_work',
      name: 'Night Work',
      description: '20mph restriction for night-time maintenance',
      reason: 'maintenance',
      restrictedSpeedMph: 20,
      normalSpeedMph: 60,
      defaultStartTime: '22:00',
      defaultEndTime: '06:00',
      defaultDuration: const Duration(hours: 8),
      isDefault: true,
    ),
    TSRTemplate(
      id: 'builtin_inspection',
      name: 'Track Inspection',
      description: '15mph restriction for detailed track inspection',
      reason: 'inspection',
      restrictedSpeedMph: 15,
      normalSpeedMph: 60,
      defaultDuration: const Duration(hours: 4),
      isDefault: true,
    ),
    TSRTemplate(
      id: 'builtin_weather',
      name: 'Weather Condition',
      description: '25mph restriction due to adverse weather conditions',
      reason: 'weather',
      restrictedSpeedMph: 25,
      normalSpeedMph: 60,
      defaultDuration: const Duration(hours: 12),
      isDefault: true,
    ),
  ];

  factory TSRTemplate.fromJson(Map<String, dynamic> json) {
    return TSRTemplate(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      reason: json['reason'] as String,
      restrictedSpeedMph: json['restricted_speed_mph'] as int,
      normalSpeedMph: json['normal_speed_mph'] as int?,
      defaultDuration: json['default_duration_hours'] != null
          ? Duration(hours: json['default_duration_hours'] as int)
          : null,
      defaultStartTime: json['default_start_time'] as String?,
      defaultEndTime: json['default_end_time'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      usageCount: json['usage_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'reason': reason,
      'restricted_speed_mph': restrictedSpeedMph,
      'normal_speed_mph': normalSpeedMph,
      'default_duration_hours': defaultDuration?.inHours,
      'default_start_time': defaultStartTime,
      'default_end_time': defaultEndTime,
      'is_default': isDefault,
      'usage_count': usageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TSRTemplate copyWith({
    String? name,
    String? description,
    String? reason,
    int? restrictedSpeedMph,
    int? normalSpeedMph,
    Duration? defaultDuration,
    String? defaultStartTime,
    String? defaultEndTime,
    int? usageCount,
  }) {
    return TSRTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      reason: reason ?? this.reason,
      restrictedSpeedMph: restrictedSpeedMph ?? this.restrictedSpeedMph,
      normalSpeedMph: normalSpeedMph ?? this.normalSpeedMph,
      defaultDuration: defaultDuration ?? this.defaultDuration,
      defaultStartTime: defaultStartTime ?? this.defaultStartTime,
      defaultEndTime: defaultEndTime ?? this.defaultEndTime,
      isDefault: isDefault,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Increment usage count
  TSRTemplate incrementUsage() {
    return copyWith(usageCount: usageCount + 1);
  }

  @override
  String toString() {
    return 'TSRTemplate{name: $name, speed: $restrictedSpeedMph mph, reason: $reason}';
  }
}

/// Saved search criteria for quick access
class SavedSearch {
  final String? id;
  final String name;
  final String description;
  final Map<String, dynamic> criteria;
  final String searchType; // 'track_section', 'tsr', 'lcs', 'platform'
  final bool isShared;
  final String? userId;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedSearch({
    this.id,
    required this.name,
    required this.description,
    required this.criteria,
    required this.searchType,
    this.isShared = false,
    this.userId,
    this.usageCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      criteria: json['criteria'] as Map<String, dynamic>,
      searchType: json['search_type'] as String,
      isShared: json['is_shared'] as bool? ?? false,
      userId: json['user_id'] as String?,
      usageCount: json['usage_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'criteria': criteria,
      'search_type': searchType,
      'is_shared': isShared,
      'user_id': userId,
      'usage_count': usageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavedSearch incrementUsage() {
    return SavedSearch(
      id: id,
      name: name,
      description: description,
      criteria: criteria,
      searchType: searchType,
      isShared: isShared,
      userId: userId,
      usageCount: usageCount + 1,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SavedSearch{name: $name, type: $searchType}';
  }
}
