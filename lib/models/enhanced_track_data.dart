// models/enhanced_track_data.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

enum LineType { DISTRICT, CIRCLE, METROPOLITAN, HAMMERSMITH_CITY }
enum TrackDirection { EASTBOUND, WESTBOUND, NORTHBOUND, SOUTHBOUND, INNER_RAIL, OUTER_RAIL }
enum StationZone { ZONE_1, ZONE_2, ZONE_3, ZONE_4, ZONE_5, ZONE_6, ZONE_7, ZONE_8, ZONE_9 }

extension LineTypeExtension on LineType {
  String get displayName {
    switch (this) {
      case LineType.DISTRICT:
        return 'District Line';
      case LineType.CIRCLE:
        return 'Circle Line';
      case LineType.METROPOLITAN:
        return 'Metropolitan Line';
      case LineType.HAMMERSMITH_CITY:
        return 'Hammersmith & City Line';
    }
  }

  Color get color {
    switch (this) {
      case LineType.DISTRICT:
        return const Color(0xFF007229); // Green
      case LineType.CIRCLE:
        return const Color(0xFFFFD329); // Yellow
      case LineType.METROPOLITAN:
        return const Color(0xFF9B0058); // Purple
      case LineType.HAMMERSMITH_CITY:
        return const Color(0xFFF689A9); // Pink
    }
  }
}

@immutable
class LCSStationMapping {
  final String lcsCode;
  final String station;
  final String line;
  final String? branch;
  final List<String> aliases;
  final double? latitude;
  final double? longitude;
  final int? zone;
  final List<String> interchanges;
  final Map<String, dynamic>? additionalData;

  const LCSStationMapping({
    required this.lcsCode,
    required this.station,
    required this.line,
    this.branch,
    this.aliases = const [],
    this.latitude,
    this.longitude,
    this.zone,
    this.interchanges = const [],
    this.additionalData,
  });

  factory LCSStationMapping.fromJson(Map<String, dynamic> json) {
    return LCSStationMapping(
      lcsCode: json['lcs_code'] ?? json['lcsCode'] ?? '',
      station: json['station'] ?? '',
      line: json['line'] ?? json['lines']?.first ?? '',
      aliases: List<String>.from(json['aliases'] ?? []),
      latitude: (json['coordinates'] ?? json['location'])?['lat']?.toDouble(),
      longitude: (json['coordinates'] ?? json['location'])?['lng']?.toDouble(),
      zone: json['zone'],
      interchanges: List<String>.from(json['interchanges'] ?? []),
      additionalData: json,
    );
  }

  LineType get lineType {
    if (line.contains('District')) return LineType.DISTRICT;
    if (line.contains('Circle')) return LineType.CIRCLE;
    if (line.contains('Metropolitan')) return LineType.METROPOLITAN;
    if (line.contains('Hammersmith')) return LineType.HAMMERSMITH_CITY;
    return LineType.DISTRICT; // Default
  }

  bool hasInterchangeWith(String lineName) {
    return interchanges.any((interchange) => 
        interchange.toLowerCase().contains(lineName.toLowerCase()));
  }

  bool matchesQuery(String query) {
    final lowerQuery = query.toLowerCase().trim();
    
    // Check LCS code
    if (lcsCode.toLowerCase().contains(lowerQuery)) return true;
    
    // Check station name
    if (station.toLowerCase().contains(lowerQuery)) return true;
    
    // Check aliases
    if (aliases.any((alias) => alias.toLowerCase().contains(lowerQuery))) return true;
    
    // Check line
    if (line.toLowerCase().contains(lowerQuery)) return true;
    
    // Check branch
    if (branch?.toLowerCase().contains(lowerQuery) == true) return true;
    
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LCSStationMapping &&
          runtimeType == other.runtimeType &&
          lcsCode == other.lcsCode;

  @override
  int get hashCode => lcsCode.hashCode;

  Map<String, dynamic> toJson() => {
        'lcsCode': lcsCode,
        'station': station,
        'line': line,
        'branch': branch,
        'aliases': aliases,
        'latitude': latitude,
        'longitude': longitude,
        'zone': zone,
        'interchanges': interchanges,
      };
}

class EnhancedTrackSection extends TrackSection {
  final LCSStationMapping? stationMapping;
  final List<LCSStationMapping> connectedStations;
  final double? estimatedLatitude;
  final double? estimatedLongitude;
  final Map<String, dynamic>? geographicData;
  final List<String> adjacentSections;
  final TrackDirection? trackDirection;
  final double? gradient;
  final double? curveRadius;
  final String? maintenanceStatus;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;

  EnhancedTrackSection({
    required super.lcsCode,
    required super.legacyLcsCode,
    required super.legacyJnpLcsCode,
    required super.roadStatus,
    required super.operatingLineCode,
    required super.operatingLine,
    required super.newLongDescription,
    required super.newShortDescription,
    required super.vcc,
    required super.thalesChainage,
    required super.segmentId,
    required super.lcsMeterageStart,
    required super.lcsMeterageEnd,
    required super.track,
    required super.trackSection,
    required super.physicalAssets,
    required super.notes,
    this.stationMapping,
    this.connectedStations = const [],
    this.estimatedLatitude,
    this.estimatedLongitude,
    this.geographicData,
    this.adjacentSections = const [],
    this.trackDirection,
    this.gradient,
    this.curveRadius,
    this.maintenanceStatus,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
  });

  factory EnhancedTrackSection.fromTrackSection(
    TrackSection section,
    LCSStationMapping? mapping, {
    List<LCSStationMapping> connected = const [],
    Map<String, dynamic>? geoData,
  }) {
    // Parse direction from LCS code or description
    final direction = _parseDirection(section.lcsCode, section.newShortDescription);
    
    // Estimate coordinates based on chainage and station
    double? lat;
    double? lng;
    
    if (mapping?.latitude != null && mapping?.longitude != null) {
      // Adjust coordinates based on meterage position within station area
      final sectionLength = section.lcsMeterageEnd - section.lcsMeterageStart;
      final positionRatio = section.lcsMeterageStart / (section.lcsMeterageEnd + 100);
      
      // Small adjustment based on position (simplified)
      lat = mapping!.latitude! + (positionRatio * 0.001);
      lng = mapping.longitude! + (positionRatio * 0.001);
    }

    return EnhancedTrackSection(
      lcsCode: section.lcsCode,
      legacyLcsCode: section.legacyLcsCode,
      legacyJnpLcsCode: section.legacyJnpLcsCode,
      roadStatus: section.roadStatus,
      operatingLineCode: section.operatingLineCode,
      operatingLine: section.operatingLine,
      newLongDescription: section.newLongDescription,
      newShortDescription: section.newShortDescription,
      vcc: section.vcc,
      thalesChainage: section.thalesChainage,
      segmentId: section.segmentId,
      lcsMeterageStart: section.lcsMeterageStart,
      lcsMeterageEnd: section.lcsMeterageEnd,
      track: section.track,
      trackSection: section.trackSection,
      physicalAssets: section.physicalAssets,
      notes: section.notes,
      stationMapping: mapping,
      connectedStations: connected,
      estimatedLatitude: lat,
      estimatedLongitude: lng,
      geographicData: geoData,
      trackDirection: direction,
    );
  }

  static TrackDirection? _parseDirection(String lcsCode, String description) {
    final lowerLcs = lcsCode.toLowerCase();
    final lowerDesc = description.toLowerCase();
    
    if (lowerLcs.contains('eb') || lowerDesc.contains('eb') || lowerDesc.contains('eastbound')) {
      return TrackDirection.EASTBOUND;
    } else if (lowerLcs.contains('wb') || lowerDesc.contains('wb') || lowerDesc.contains('westbound')) {
      return TrackDirection.WESTBOUND;
    } else if (lowerLcs.contains('ir') || lowerDesc.contains('inner')) {
      return TrackDirection.INNER_RAIL;
    } else if (lowerLcs.contains('or') || lowerDesc.contains('outer')) {
      return TrackDirection.OUTER_RAIL;
    } else if (lowerDesc.contains('northbound')) {
      return TrackDirection.NORTHBOUND;
    } else if (lowerDesc.contains('southbound')) {
      return TrackDirection.SOUTHBOUND;
    }
    
    return null;
  }

  String get primaryStation => stationMapping?.station ?? _extractStationFromDescription();
  String get primaryLine => stationMapping?.line ?? operatingLine;
  List<String> getAllLines() {
    final lines = <String>{operatingLine};
    if (stationMapping != null) {
      lines.add(stationMapping!.line);
    }
    for (var station in connectedStations) {
      lines.add(station.line);
    }
    return lines.toList();
  }

  String _extractStationFromDescription() {
    // Try to extract station from description
    final desc = newShortDescription.toLowerCase();
    
    // Common station patterns in descriptions
    final stationPatterns = [
      'stn',
      'station',
      'road',
      'street',
      'lane',
      'park',
      'court',
      'square',
      'cross',
      'gate',
    ];
    
    for (var pattern in stationPatterns) {
      final index = desc.indexOf(pattern);
      if (index > 0) {
        // Extract text before the pattern
        var stationPart = desc.substring(0, index).trim();
        // Clean up common prefixes
        stationPart = stationPart
            .replaceAll('plt', '')
            .replaceAll('pl', '')
            .replaceAll('to', '')
            .replaceAll('from', '')
            .replaceAll('between', '')
            .trim();
        
        if (stationPart.isNotEmpty) {
          // Capitalize first letter of each word
          return stationPart.split(' ').map((word) {
            if (word.isNotEmpty) {
              return word[0].toUpperCase() + word.substring(1);
            }
            return word;
          }).join(' ');
        }
      }
    }
    
    return 'Unknown Location';
  }

  double calculateDistanceTo(double meterage) {
    if (meterage < lcsMeterageStart) {
      return lcsMeterageStart - meterage;
    } else if (meterage > lcsMeterageEnd) {
      return meterage - lcsMeterageEnd;
    } else {
      return 0; // Within section
    }
  }

  bool isWithinRadiusOfStation(LCSStationMapping station, double radiusMeters) {
    if (estimatedLatitude == null || estimatedLongitude == null ||
        station.latitude == null || station.longitude == null) {
      return false;
    }
    
    final distance = _calculateDistance(
      estimatedLatitude!,
      estimatedLongitude!,
      station.latitude!,
      station.longitude!,
    );
    
    return distance <= radiusMeters;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  List<LCSStationMapping> getNearbyStations(List<LCSStationMapping> allStations, double radiusMeters) {
    return allStations.where((station) {
      return isWithinRadiusOfStation(station, radiusMeters) &&
          station.lcsCode != stationMapping?.lcsCode;
    }).toList();
  }

  Map<String, dynamic> toEnhancedJson() => {
        ...toJson(),
        'stationMapping': stationMapping?.toJson(),
        'primaryStation': primaryStation,
        'allLines': getAllLines(),
        'estimatedLatitude': estimatedLatitude,
        'estimatedLongitude': estimatedLongitude,
        'trackDirection': trackDirection?.toString(),
        'maintenanceStatus': maintenanceStatus,
        'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String(),
        'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
        'adjacentSections': adjacentSections,
      };
}

class EnhancedQueryResult {
  final EnhancedTrackSection? nearestSection;
  final LCSStationMapping? nearestStation;
  final double inputMeterage;
  final double distanceToNearestStation;
  final String? inputLcsCode;
  final List<LCSStationMapping> nearbyStations;
  final List<EnhancedTrackSection> nearbySections;
  final Map<String, dynamic>? networkConnections;
  final List<String> suggestedActions;
  final DateTime queryTimestamp;

  const EnhancedQueryResult({
    this.nearestSection,
    this.nearestStation,
    required this.inputMeterage,
    this.distanceToNearestStation = 0,
    this.inputLcsCode,
    this.nearbyStations = const [],
    this.nearbySections = const [],
    this.networkConnections,
    this.suggestedActions = const [],
    required this.queryTimestamp,
  });

  factory EnhancedQueryResult.fromBasic(
    QueryResult basicResult, {
    List<LCSStationMapping> nearbyStations = const [],
    List<EnhancedTrackSection> nearbySections = const [],
    Map<String, dynamic>? connections,
  }) {
    return EnhancedQueryResult(
      nearestSection: basicResult.nearestSection != null
          ? EnhancedTrackSection.fromTrackSection(
              basicResult.nearestSection!,
              null,
            )
          : null,
      nearestStation: basicResult.nearestLocation != null
          ? LCSStationMapping(
              lcsCode: basicResult.nearestLocation!.code,
              station: basicResult.nearestLocation!.name,
              line: basicResult.nearestLocation!.line,
            )
          : null,
      inputMeterage: basicResult.inputMeterage,
      distanceToNearestStation: basicResult.distanceToNearestLocation,
      inputLcsCode: basicResult.inputLcsCode,
      nearbyStations: nearbyStations,
      nearbySections: nearbySections,
      networkConnections: connections,
      queryTimestamp: DateTime.now(),
      suggestedActions: _generateSuggestedActions(basicResult),
    );
  }

  static List<String> _generateSuggestedActions(QueryResult result) {
    final actions = <String>[];
    
    if (result.nearestSection != null) {
      actions.add('View detailed section information');
      actions.add('Check maintenance schedule');
      
      if (result.nearestLocation != null) {
        actions.add('Navigate to ${result.nearestLocation!.name}');
      }
    }
    
    if (result.inputLcsCode != null) {
      actions.add('Search for similar LCS codes');
      actions.add('Export section data');
    }
    
    return actions;
  }

  bool get hasStationConnection => nearestStation != null;
  bool get hasMultipleLines => (nearestSection?.getAllLines().length ?? 0) > 1;
  bool get isAtStation => distanceToNearestStation < 50; // Within 50 meters
  bool get hasNetworkConnections => networkConnections?.isNotEmpty == true;

  List<String> getInterchangeLines() {
    final lines = <String>{};
    
    if (nearestStation?.interchanges.isNotEmpty == true) {
      lines.addAll(nearestStation!.interchanges);
    }
    
    if (networkConnections?.containsKey('Interchange') == true) {
      final interchangeLines = networkConnections!['Interchange'] as List<String>;
      lines.addAll(interchangeLines);
    }
    
    return lines.toList();
  }

  Map<String, dynamic> toJson() => {
        'nearestSection': nearestSection?.toEnhancedJson(),
        'nearestStation': nearestStation?.toJson(),
        'inputMeterage': inputMeterage,
        'distanceToNearestStation': distanceToNearestStation,
        'inputLcsCode': inputLcsCode,
        'nearbyStations': nearbyStations.map((s) => s.toJson()).toList(),
        'nearbySections': nearbySections.map((s) => s.toEnhancedJson()).toList(),
        'networkConnections': networkConnections,
        'suggestedActions': suggestedActions,
        'queryTimestamp': queryTimestamp.toIso8601String(),
        'hasStationConnection': hasStationConnection,
        'hasMultipleLines': hasMultipleLines,
        'isAtStation': isAtStation,
        'interchangeLines': getInterchangeLines(),
      };
}

class NetworkGraph {
  final Map<String, List<String>> adjacencyList;
  final Map<String, LCSStationMapping> stations;
  final Map<String, List<EnhancedTrackSection>> stationSections;

  NetworkGraph({
    required this.adjacencyList,
    required this.stations,
    required this.stationSections,
  });

  factory NetworkGraph.fromStationsAndSections(
    List<LCSStationMapping> allStations,
    List<EnhancedTrackSection> allSections,
  ) {
    final adjacency = <String, List<String>>{};
    final stationMap = <String, LCSStationMapping>{};
    final sectionsMap = <String, List<EnhancedTrackSection>>{};
    
    // Build station map
    for (var station in allStations) {
      stationMap[station.lcsCode] = station;
      sectionsMap[station.lcsCode] = [];
    }
    
    // Build sections map
    for (var section in allSections) {
      if (section.stationMapping != null) {
        sectionsMap[section.stationMapping!.lcsCode]?.add(section);
      }
    }
    
    // Build adjacency based on line connections and proximity
    for (var station1 in allStations) {
      final neighbors = <String>[];
      
      for (var station2 in allStations) {
        if (station1.lcsCode == station2.lcsCode) continue;
        
        // Connect stations on same line
        if (station1.line == station2.line) {
          neighbors.add(station2.lcsCode);
        }
        
        // Connect interchange stations
        if (station1.hasInterchangeWith(station2.line) ||
            station2.hasInterchangeWith(station1.line)) {
          neighbors.add(station2.lcsCode);
        }
      }
      
      adjacency[station1.lcsCode] = neighbors;
    }
    
    return NetworkGraph(
      adjacencyList: adjacency,
      stations: stationMap,
      stationSections: sectionsMap,
    );
  }

  List<String> findShortestPath(String startLcs, String endLcs) {
    if (!adjacencyList.containsKey(startLcs) || !adjacencyList.containsKey(endLcs)) {
      return [];
    }
    
    final queue = <List<String>>[];
    final visited = <String>{};
    
    queue.add([startLcs]);
    
    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final node = path.last;
      
      if (node == endLcs) {
        return path;
      }
      
      if (!visited.contains(node)) {
        visited.add(node);
        
        for (var neighbor in adjacencyList[node] ?? []) {
          final newPath = List<String>.from(path)..add(neighbor);
          queue.add(newPath);
        }
      }
    }
    
    return [];
  }

  List<LCSStationMapping> getStationsOnPath(List<String> path) {
    return path.map((lcs) => stations[lcs]!).whereType<LCSStationMapping>().toList();
  }

  double estimateTravelTime(List<String> path, {double speedKph = 30.0}) {
    // Simplified estimation based on number of stations
    // In reality, this would use actual distances
    final stationCount = path.length;
    final avgTimePerStation = 2.0; // minutes
    return stationCount * avgTimePerStation;
  }
}