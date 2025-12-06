// models/track_data.dart
import 'package:flutter/foundation.dart';

/// Represents a physical location on the railway network
@immutable
class Location {
  final String code;
  final String name;
  final String line;
  final double referenceMeterage;
  final double? latitude;
  final double? longitude;
  final int? zone;

  const Location({
    required this.code,
    required this.name,
    required this.line,
    required this.referenceMeterage,
    this.latitude,
    this.longitude,
    this.zone,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      code: json['code'] ?? json['lcs_code'] ?? '',
      name: json['name'] ?? json['station'] ?? '',
      line: json['line'] ?? '',
      referenceMeterage: (json['referenceMeterage'] ?? json['meterage'] ?? 0).toDouble(),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      zone: json['zone'],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'line': line,
        'referenceMeterage': referenceMeterage,
        'latitude': latitude,
        'longitude': longitude,
        'zone': zone,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Represents a track section on the railway network
@immutable
class TrackSection {
  final String lcsCode;
  final String legacyLcsCode;
  final String legacyJnpLcsCode;
  final String roadStatus;
  final String operatingLineCode;
  final String operatingLine;
  final String newLongDescription;
  final String newShortDescription;
  final String vcc;
  final String thalesChainage;
  final String segmentId;
  final double lcsMeterageStart;
  final double lcsMeterageEnd;
  final String track;
  final String trackSection;
  final String physicalAssets;
  final String notes;

  const TrackSection({
    required this.lcsCode,
    required this.legacyLcsCode,
    required this.legacyJnpLcsCode,
    required this.roadStatus,
    required this.operatingLineCode,
    required this.operatingLine,
    required this.newLongDescription,
    required this.newShortDescription,
    required this.vcc,
    required this.thalesChainage,
    required this.segmentId,
    required this.lcsMeterageStart,
    required this.lcsMeterageEnd,
    required this.track,
    required this.trackSection,
    this.physicalAssets = '',
    this.notes = '',
  });

  factory TrackSection.fromJson(Map<String, dynamic> json) {
    return TrackSection(
      lcsCode: json['lcsCode'] ?? json['LCS_Code'] ?? '',
      legacyLcsCode: json['legacyLcsCode'] ?? json['Legacy_LCS_Code'] ?? '',
      legacyJnpLcsCode: json['legacyJnpLcsCode'] ?? json['Legacy_JNP_LCS_Code'] ?? '',
      roadStatus: json['roadStatus'] ?? json['Road_Status'] ?? '',
      operatingLineCode: json['operatingLineCode'] ?? json['Operating_Line_Code'] ?? '',
      operatingLine: json['operatingLine'] ?? json['Operating_Line'] ?? '',
      newLongDescription: json['newLongDescription'] ?? json['New_Long_Description'] ?? '',
      newShortDescription: json['newShortDescription'] ?? json['New_Short_Description'] ?? '',
      vcc: json['vcc'] ?? json['VCC'] ?? '',
      thalesChainage: json['thalesChainage'] ?? json['Thales_Chainage'] ?? '',
      segmentId: json['segmentId'] ?? json['Segment_ID'] ?? '',
      lcsMeterageStart: (json['lcsMeterageStart'] ?? json['LCS_Meterage_Start'] ?? 0).toDouble(),
      lcsMeterageEnd: (json['lcsMeterageEnd'] ?? json['LCS_Meterage_End'] ?? 0).toDouble(),
      track: json['track'] ?? json['Track'] ?? '',
      trackSection: json['trackSection'] ?? json['Track_Section'] ?? '',
      physicalAssets: json['physicalAssets'] ?? json['Physical_Assets'] ?? '',
      notes: json['notes'] ?? json['Notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'lcsCode': lcsCode,
        'legacyLcsCode': legacyLcsCode,
        'legacyJnpLcsCode': legacyJnpLcsCode,
        'roadStatus': roadStatus,
        'operatingLineCode': operatingLineCode,
        'operatingLine': operatingLine,
        'newLongDescription': newLongDescription,
        'newShortDescription': newShortDescription,
        'vcc': vcc,
        'thalesChainage': thalesChainage,
        'segmentId': segmentId,
        'lcsMeterageStart': lcsMeterageStart,
        'lcsMeterageEnd': lcsMeterageEnd,
        'track': track,
        'trackSection': trackSection,
        'physicalAssets': physicalAssets,
        'notes': notes,
      };

  /// Check if this section contains the given meterage value
  bool isWithinMeterage(double meterage) {
    return meterage >= lcsMeterageStart && meterage <= lcsMeterageEnd;
  }

  /// Get the length of this section in meters
  double get length => lcsMeterageEnd - lcsMeterageStart;

  /// Get the midpoint meterage of this section
  double get midpointMeterage => (lcsMeterageStart + lcsMeterageEnd) / 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackSection &&
          runtimeType == other.runtimeType &&
          lcsCode == other.lcsCode &&
          segmentId == other.segmentId;

  @override
  int get hashCode => lcsCode.hashCode ^ segmentId.hashCode;
}

/// Represents the result of a query for track information
@immutable
class QueryResult {
  final TrackSection? nearestSection;
  final Location? nearestLocation;
  final double inputMeterage;
  final double distanceToNearestLocation;
  final String? inputLcsCode;

  const QueryResult({
    this.nearestSection,
    this.nearestLocation,
    required this.inputMeterage,
    this.distanceToNearestLocation = 0,
    this.inputLcsCode,
  });

  bool get hasResults => nearestSection != null || nearestLocation != null;

  bool get isExactMatch =>
      nearestSection != null &&
      nearestSection!.isWithinMeterage(inputMeterage);

  Map<String, dynamic> toJson() => {
        'nearestSection': nearestSection?.toJson(),
        'nearestLocation': nearestLocation?.toJson(),
        'inputMeterage': inputMeterage,
        'distanceToNearestLocation': distanceToNearestLocation,
        'inputLcsCode': inputLcsCode,
        'hasResults': hasResults,
        'isExactMatch': isExactMatch,
      };

  @override
  String toString() {
    return 'QueryResult(inputMeterage: $inputMeterage, '
        'distanceToNearestLocation: $distanceToNearestLocation, '
        'hasResults: $hasResults)';
  }
}

/// Track section statistics and summary information
class TrackSectionStats {
  final int totalSections;
  final int totalLines;
  final double totalTrackLength;
  final Map<String, int> sectionsByLine;
  final Map<String, double> lengthByLine;

  const TrackSectionStats({
    required this.totalSections,
    required this.totalLines,
    required this.totalTrackLength,
    required this.sectionsByLine,
    required this.lengthByLine,
  });

  Map<String, dynamic> toJson() => {
        'totalSections': totalSections,
        'totalLines': totalLines,
        'totalTrackLength': totalTrackLength,
        'sectionsByLine': sectionsByLine,
        'lengthByLine': lengthByLine,
      };
}
