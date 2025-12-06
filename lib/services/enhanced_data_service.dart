// services/enhanced_data_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../models/enhanced_track_data.dart';
import '../models/track_data.dart';
import 'data_service.dart';

class EnhancedDataService {
  static final EnhancedDataService _instance = EnhancedDataService._internal();
  factory EnhancedDataService() => _instance;
  EnhancedDataService._internal();

  List<LCSStationMapping> _stationMappings = [];
  List<EnhancedTrackSection> _enhancedSections = [];

  Future<void> initialize() async {
    await _loadStationMappings();
    await _loadTrackSections();
    await _enhanceSectionsWithMappings();
  }

  Future<void> _loadStationMappings() async {
    try {
      final data = await rootBundle.loadString('assets/lcs_mappings.xml');
      final document = XmlDocument.parse(data);
      
      _stationMappings = document.findAllElements('Entry').map((element) {
        return LCSStationMapping(
          lcsCode: element.findElements('LCS_Code').first.innerText,
          station: element.findElements('Station').first.innerText,
          line: element.findElements('Line').first.innerText,
        );
      }).toList();
    } catch (e) {
      // Fallback to embedded data
      _stationMappings = _getSampleMappings();
    }
  }

  Future<void> _loadTrackSections() async {
    // Load original track sections as before
    final dataService = DataService();
    await dataService.initialize();
  }

  Future<void> _enhanceSectionsWithMappings() async {
    final originalSections = DataService().getTrackSections();
    
    _enhancedSections = originalSections.map((section) {
      // Find matching station mapping
      LCSStationMapping? mapping;
      
      // Try exact LCS code match first
      try {
        mapping = _stationMappings.firstWhere(
          (m) => m.lcsCode == section.lcsCode,
        );
      } catch (e) {
        try {
          mapping = _stationMappings.firstWhere(
            (m) => _doesLcsMatch(section.lcsCode, m.lcsCode),
          );
        } catch (e) {
          mapping = _findMappingByStationName(section);
        }
      }
      
      return EnhancedTrackSection.fromTrackSection(section, mapping);
    }).toList();
  }

  bool _doesLcsMatch(String sectionCode, String mappingCode) {
    // Handle variations like M173/MORLO vs M173
    final cleanSection = sectionCode.split('/').first.split('-').first;
    final cleanMapping = mappingCode.split('/').first.split('-').first;
    return cleanSection == cleanMapping;
  }

  LCSStationMapping? _findMappingByStationName(TrackSection section) {
    final description = section.newShortDescription.toLowerCase();
    
    for (var mapping in _stationMappings) {
      final stationName = mapping.station.toLowerCase();
      
      // Check if station name appears in description
      if (description.contains(stationName)) {
        return mapping;
      }
      
      // Check aliases
      for (var alias in mapping.aliases) {
        if (description.contains(alias.toLowerCase())) {
          return mapping;
        }
      }
    }
    
    return null;
  }

  EnhancedQueryResult enhancedSearchByMeterage(double meterage, {double radius = 100}) {
    // Find containing sections
    final containingSections = _enhancedSections
        .where((section) => section.isWithinMeterage(meterage))
        .toList();

    // Find nearest station
    LCSStationMapping? nearestStation;
    double minStationDistance = double.infinity;
    
    for (var mapping in _stationMappings) {
      // Find corresponding sections for this station
      final stationSections = _enhancedSections
          .where((section) => section.stationMapping?.lcsCode == mapping.lcsCode)
          .toList();
      
      if (stationSections.isNotEmpty) {
        final avgMeterage = stationSections
            .map((s) => (s.lcsMeterageStart + s.lcsMeterageEnd) / 2)
            .reduce((a, b) => a + b) / stationSections.length;
        
        final distance = (avgMeterage - meterage).abs();
        if (distance < minStationDistance) {
          minStationDistance = distance;
          nearestStation = mapping;
        }
      }
    }

    // Find nearby stations within radius
    final nearbyStations = _stationMappings.where((mapping) {
      final stationSections = _enhancedSections
          .where((section) => section.stationMapping?.lcsCode == mapping.lcsCode)
          .toList();
      
      if (stationSections.isEmpty) return false;
      
      final avgMeterage = stationSections
          .map((s) => (s.lcsMeterageStart + s.lcsMeterageEnd) / 2)
          .reduce((a, b) => a + b) / stationSections.length;
      
      return (avgMeterage - meterage).abs() <= radius;
    }).toList();

    // Find nearby sections
    final nearbySections = _enhancedSections.where((section) {
      final distance = section.calculateDistanceTo(meterage);
      return distance <= radius;
    }).toList();

    EnhancedTrackSection? nearestSection;
    if (containingSections.isNotEmpty) {
      nearestSection = containingSections.first;
    } else {
      // Find nearest section
      double minSectionDistance = double.infinity;
      for (var section in _enhancedSections) {
        final distance = section.calculateDistanceTo(meterage);
        if (distance < minSectionDistance) {
          minSectionDistance = distance;
          nearestSection = section;
        }
      }
    }

    return EnhancedQueryResult(
      nearestSection: nearestSection,
      nearestStation: nearestStation,
      inputMeterage: meterage,
      distanceToNearestStation: minStationDistance,
      nearbyStations: nearbyStations,
      nearbySections: nearbySections,
      queryTimestamp: DateTime.now(),
    );
  }

  EnhancedQueryResult enhancedSearchByLcsCode(String lcsCode) {
    // Find exact match
    var mapping = _stationMappings.firstWhere(
      (m) => m.lcsCode == lcsCode,
      orElse: () => _stationMappings.firstWhere(
        (m) => m.lcsCode.contains(lcsCode) || lcsCode.contains(m.lcsCode),
        orElse: () => throw Exception('LCS code not found'),
      ),
    );

    // Find corresponding sections
    final sections = _enhancedSections
        .where((section) => section.stationMapping?.lcsCode == mapping.lcsCode)
        .toList();

    if (sections.isEmpty) {
      // Try fuzzy matching
      final fuzzySections = _enhancedSections
          .where((section) => 
              section.lcsCode.contains(lcsCode) ||
              section.legacyLcsCode.contains(lcsCode))
          .toList();
      
      if (fuzzySections.isEmpty) {
        return EnhancedQueryResult(
          inputMeterage: 0,
          inputLcsCode: lcsCode,
          queryTimestamp: DateTime.now(),
        );
      }

      final section = fuzzySections.first;
      return EnhancedQueryResult(
        nearestSection: section,
        nearestStation: section.stationMapping,
        inputMeterage: section.lcsMeterageStart,
        inputLcsCode: lcsCode,
        distanceToNearestStation: 0,
        queryTimestamp: DateTime.now(),
      );
    }

    final primarySection = sections.first;
    final avgMeterage = sections
        .map((s) => (s.lcsMeterageStart + s.lcsMeterageEnd) / 2)
        .reduce((a, b) => a + b) / sections.length;

    // Find nearby stations
    final nearbyStations = _stationMappings.where((otherMapping) {
      if (otherMapping.lcsCode == mapping.lcsCode) return false;
      
      final otherSections = _enhancedSections
          .where((section) => section.stationMapping?.lcsCode == otherMapping.lcsCode)
          .toList();
      
      if (otherSections.isEmpty) return false;
      
      final otherAvgMeterage = otherSections
          .map((s) => (s.lcsMeterageStart + s.lcsMeterageEnd) / 2)
          .reduce((a, b) => a + b) / otherSections.length;
      
      return (otherAvgMeterage - avgMeterage).abs() <= 500; // Within 500m
    }).toList();

    return EnhancedQueryResult(
      nearestSection: primarySection,
      nearestStation: mapping,
      inputMeterage: avgMeterage,
      inputLcsCode: lcsCode,
      distanceToNearestStation: 0,
      nearbyStations: nearbyStations,
      nearbySections: sections,
      queryTimestamp: DateTime.now(),
    );
  }

  List<LCSStationMapping> searchStations(String query) {
    return _stationMappings
        .where((mapping) => mapping.matchesQuery(query))
        .toList();
  }

  /// Search for partial LCS code matches and return shortlist
  List<LCSStationMapping> searchPartialLcsCode(String partialCode) {
    if (partialCode.isEmpty) return [];

    final cleanQuery = partialCode.toUpperCase().trim();
    final results = <LCSStationMapping>[];

    // Exact match first
    final exactMatches = _stationMappings
        .where((m) => m.lcsCode.toUpperCase() == cleanQuery)
        .toList();
    results.addAll(exactMatches);

    // Starts with match
    if (results.isEmpty) {
      final startsWithMatches = _stationMappings
          .where((m) => m.lcsCode.toUpperCase().startsWith(cleanQuery))
          .toList();
      results.addAll(startsWithMatches);
    }

    // Contains match (broader search)
    if (results.isEmpty || results.length < 5) {
      final containsMatches = _stationMappings
          .where((m) =>
              m.lcsCode.toUpperCase().contains(cleanQuery) &&
              !results.contains(m))
          .toList();
      results.addAll(containsMatches);
    }

    // Sort by relevance: exact > starts with > contains
    results.sort((a, b) {
      final aCode = a.lcsCode.toUpperCase();
      final bCode = b.lcsCode.toUpperCase();

      if (aCode == cleanQuery && bCode != cleanQuery) return -1;
      if (aCode != cleanQuery && bCode == cleanQuery) return 1;

      if (aCode.startsWith(cleanQuery) && !bCode.startsWith(cleanQuery)) return -1;
      if (!aCode.startsWith(cleanQuery) && bCode.startsWith(cleanQuery)) return 1;

      return aCode.compareTo(bCode);
    });

    return results;
  }

  /// Get all track sections matching a partial LCS code
  List<EnhancedTrackSection> searchPartialTrackSections(String partialCode) {
    if (partialCode.isEmpty) return [];

    final cleanQuery = partialCode.toUpperCase().trim();
    final results = <EnhancedTrackSection>[];

    // Search in enhanced sections
    results.addAll(_enhancedSections.where((section) {
      final lcsCode = section.lcsCode.toUpperCase();
      final legacyCode = section.legacyLcsCode.toUpperCase();

      return lcsCode.contains(cleanQuery) || legacyCode.contains(cleanQuery);
    }));

    // Sort by relevance
    results.sort((a, b) {
      final aExact = a.lcsCode.toUpperCase() == cleanQuery;
      final bExact = b.lcsCode.toUpperCase() == cleanQuery;

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      final aStarts = a.lcsCode.toUpperCase().startsWith(cleanQuery);
      final bStarts = b.lcsCode.toUpperCase().startsWith(cleanQuery);

      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return a.lcsMeterageStart.compareTo(b.lcsMeterageStart);
    });

    return results;
  }

  List<LCSStationMapping> getStationsOnLine(String line) {
    return _stationMappings
        .where((mapping) => mapping.line == line)
        .toList();
  }

  List<EnhancedTrackSection> getSectionsForStation(String stationName) {
    return _enhancedSections
        .where((section) => 
            section.stationMapping?.station == stationName ||
            section.stationMapping?.aliases.contains(stationName) == true)
        .toList();
  }

  Map<String, dynamic> getNetworkConnections(String lcsCode) {
    final mapping = _stationMappings.firstWhere(
      (m) => m.lcsCode == lcsCode,
      orElse: () => throw Exception('Station not found'),
    );

    final sections = getSectionsForStation(mapping.station);
    final connections = <String, List<String>>{};

    // Find stations on the same line
    final sameLineStations = getStationsOnLine(mapping.line)
        .where((m) => m.lcsCode != lcsCode)
        .map((m) => m.station)
        .toList();

    connections[mapping.line] = sameLineStations;

    // Find interchanges (stations that appear in multiple sections)
    for (var section in sections) {
      for (var otherSection in _enhancedSections) {
        if (otherSection.lcsCode != section.lcsCode &&
            otherSection.stationMapping != null &&
            otherSection.stationMapping!.station == mapping.station) {
          // This station has multiple LCS codes (interchange)
          if (!connections.containsKey('Interchange')) {
            connections['Interchange'] = [];
          }
          connections['Interchange']!.add(otherSection.stationMapping!.line);
        }
      }
    }

    return {
      'station': mapping.station,
      'lcs_code': mapping.lcsCode,
      'primary_line': mapping.line,
      'connections': connections,
      'sections_count': sections.length,
    };
  }

  List<LCSStationMapping> _getSampleMappings() {
    return [
      LCSStationMapping(
        lcsCode: 'D011',
        station: 'Upminster',
        line: 'District Line',
      ),
      LCSStationMapping(
        lcsCode: 'D013',
        station: 'Upminster Bridge',
        line: 'District Line',
      ),
      LCSStationMapping(
        lcsCode: 'M173',
        station: 'Royal Oak',
        line: 'Hammersmith & City Line',
      ),
      LCSStationMapping(
        lcsCode: 'B077',
        station: 'Baker Street',
        line: 'Metropolitan Line',
        aliases: ['Baker St', 'BSS'],
      ),
      // Add more mappings...
    ];
  }
}