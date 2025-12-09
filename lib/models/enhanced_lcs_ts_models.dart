/// Enhanced data models incorporating LCS_Map XML and comprehensive track section data
import 'track_data.dart';

class LcsStationMapping {
  final String lcsCode;
  final String station;
  final String line;

  LcsStationMapping({
    required this.lcsCode,
    required this.station,
    required this.line,
  });

  factory LcsStationMapping.fromXml(Map<String, dynamic> xml) {
    return LcsStationMapping(
      lcsCode: (xml['LCS_Code'] ?? '').toString(),
      station: (xml['Station'] ?? '').toString(),
      line: (xml['Line'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lcsCode': lcsCode,
        'station': station,
        'line': line,
      };
}

class EnhancedTrackSection {
  final String id;
  final String currentLcsCode;
  final String legacyLcsCode;
  final String? legacyJnpLcsCode;
  final String roadStatus;
  final String operatingLineCode;
  final String operatingLine;
  final String newLongDescription;
  final String newShortDescription;
  final double vcc;
  final double thalesChainage;
  final String segmentId;
  final double lcsMeterageStart;
  final double lcsMeterageEnd;
  final String track;
  final String trackSection;
  final String? physicalAssets;
  final String? notes;

  EnhancedTrackSection({
    required this.id,
    required this.currentLcsCode,
    required this.legacyLcsCode,
    this.legacyJnpLcsCode,
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
    this.physicalAssets,
    this.notes,
  });

  factory EnhancedTrackSection.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    return EnhancedTrackSection(
      id: (json['id'] ?? '').toString(),
      currentLcsCode: (json['CURRENT_LCS_CODE'] ?? '').toString(),
      legacyLcsCode: (json['LEGACY_LCS_CODE'] ?? '').toString(),
      legacyJnpLcsCode: json['LEGACY_JNP_LCS_Code']?.toString(),
      roadStatus: (json['Road Status'] ?? '').toString(),
      operatingLineCode: (json['Operating Line Code'] ?? '').toString(),
      operatingLine: (json['Operating Line'] ?? '').toString(),
      newLongDescription: (json['NEW LONG DESCRIPION'] ?? '').toString(),
      newShortDescription: (json['NEW SHORT DESCRIPION'] ?? '').toString(),
      vcc: _toDouble(json['VCC']),
      thalesChainage: _toDouble(json['Thales Chainage']),
      segmentId: (json['Segment ID'] ?? '').toString(),
      lcsMeterageStart: _toDouble(json['LCS Meterage Start']),
      lcsMeterageEnd: _toDouble(json['LCS Meterage End']),
      track: (json['Track'] ?? '').toString(),
      trackSection: (json['Track Section'] ?? '').toString(),
      physicalAssets: json['Physical assets']?.toString(),
      notes: json['Notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'CURRENT_LCS_CODE': currentLcsCode,
        'LEGACY_LCS_CODE': legacyLcsCode,
        'LEGACY_JNP_LCS_Code': legacyJnpLcsCode,
        'Road Status': roadStatus,
        'Operating Line Code': operatingLineCode,
        'Operating Line': operatingLine,
        'NEW LONG DESCRIPION': newLongDescription,
        'NEW SHORT DESCRIPION': newShortDescription,
        'VCC': vcc,
        'Thales Chainage': thalesChainage,
        'Segment ID': segmentId,
        'LCS Meterage Start': lcsMeterageStart,
        'LCS Meterage End': lcsMeterageEnd,
        'Track': track,
        'Track Section': trackSection,
        'Physical assets': physicalAssets,
        'Notes': notes,
      };

  /// Convert EnhancedTrackSection to TrackSection
  TrackSection toTrackSection() {
    return TrackSection(
      lcsCode: currentLcsCode,
      legacyLcsCode: legacyLcsCode,
      legacyJnpLcsCode: legacyJnpLcsCode ?? '',
      roadStatus: roadStatus,
      operatingLineCode: operatingLineCode,
      operatingLine: operatingLine,
      newLongDescription: newLongDescription,
      newShortDescription: newShortDescription,
      vcc: vcc.toString(),
      thalesChainage: thalesChainage.toString(),
      segmentId: segmentId,
      lcsMeterageStart: lcsMeterageStart,
      lcsMeterageEnd: lcsMeterageEnd,
      track: track,
      trackSection: trackSection,
      physicalAssets: physicalAssets ?? '',
      notes: notes ?? '',
    );
  }

  int get trackSectionId => int.tryParse(trackSection) ?? 0;
}

class SearchResult {
  final EnhancedTrackSection trackSection;
  final LcsStationMapping? stationMapping;
  final double? distanceFromSearchPoint;
  final bool isNearestMatch;
  final List<String> platforms;

  SearchResult({
    required this.trackSection,
    this.stationMapping,
    this.distanceFromSearchPoint,
    this.isNearestMatch = false,
    this.platforms = const [],
  });
}

class LocationInfo {
  final String station;
  final String line;
  final String lcsCode;
  final double chainage;
  final double meterage;
  final List<int> trackSections;
  final List<String> platforms;

  LocationInfo({
    required this.station,
    required this.line,
    required this.lcsCode,
    required this.chainage,
    required this.meterage,
    this.trackSections = const [],
    this.platforms = const [],
  });
}

class NearestChainageResult {
  final double originalMeterage;
  final double correctedMeterage;
  final double distance;
  final bool wasCorrected;
  final double? nearestChainage;

  NearestChainageResult({
    required this.originalMeterage,
    required this.correctedMeterage,
    required this.distance,
    required this.wasCorrected,
    this.nearestChainage,
  });
}

