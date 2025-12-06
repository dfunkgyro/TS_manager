import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_track_data.dart';
import 'package:track_sections_manager/models/track_data.dart';
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show LocationInfo, NearestChainageResult;

/// Enhanced service with partial matching, nearest chainage, and comprehensive data
class EnhancedLcsTsService {
  static EnhancedLcsTsService? _instance;
  LcsTsAppData? _cachedData;
  List<LCSStationMapping> _stationMappings = [];
  List<EnhancedTrackSection> _enhancedTrackSections = [];
  Map<String, List<LCSStationMapping>> _lcsToStations = {};

  EnhancedLcsTsService._();

  factory EnhancedLcsTsService() {
    _instance ??= EnhancedLcsTsService._();
    return _instance!;
  }

  /// Load all data including LCS_Map XML and enhanced track sections
  Future<void> loadAllData() async {
    await Future.wait([
      _loadLcsTsData(),
      _loadStationMappings(),
      _loadEnhancedTrackSections(),
    ]);
    _buildIndices();
  }

  Future<void> _loadLcsTsData() async {
    try {
      final lcsRaw = await rootBundle.loadString('assets/data/lcs.json');
      final tsRaw = await rootBundle.loadString('assets/data/ts.json');
      
      List<PlatformRecord> platformList = [];
      try {
        final platRaw = await rootBundle.loadString('assets/data/platform_ts.json');
        final platJson = jsonDecode(platRaw) as List<dynamic>;
        platformList = platJson
            .map((e) => PlatformRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Warning: Could not load platform data: $e');
      }

      final lcsJson = jsonDecode(lcsRaw) as List<dynamic>;
      final tsJson = jsonDecode(tsRaw) as List<dynamic>;

      final lcsList = lcsJson
          .map((e) => LcsRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      final tsList = tsJson
          .map((e) => TsRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<int, List<String>> platformsByTs = {};
      for (final p in platformList) {
        for (final ts in p.trackSections) {
          platformsByTs.putIfAbsent(ts, () => []).add(p.platform);
        }
      }

      _cachedData = LcsTsAppData(
        lcsList: lcsList,
        tsList: tsList,
        platformList: platformList,
        platformsByTs: platformsByTs,
      );
    } catch (e) {
      print('Error loading LCS/TS data: $e');
    }
  }

  Future<void> _loadStationMappings() async {
    try {
      final data = await rootBundle.loadString('assets/data/lcs_mappings.xml');
      final document = XmlDocument.parse(data);
      
      _stationMappings = document.findAllElements('Entry').map((element) {
        final lcsCode = element.findElements('LCS_Code').first.innerText;
        final station = element.findElements('Station').first.innerText;
        final line = element.findElements('Line').first.innerText;
        
        return LCSStationMapping(
          lcsCode: lcsCode,
          station: station,
          line: line,
          aliases: const [],
        );
      }).toList();
    } catch (e) {
      print('Error loading station mappings: $e');
    }
  }

  Future<void> _loadEnhancedTrackSections() async {
    // Load from the comprehensive JSON data provided by user
    // For now, we'll create enhanced sections from existing TS data
    if (_cachedData == null) return;
    
    _enhancedTrackSections = _cachedData!.tsList.map((ts) {
      LcsRecord lcs;
      try {
        lcs = _cachedData!.lcsList.firstWhere(
          (l) => l.vcc == ts.vcc && 
                 ts.chainageStart >= l.chainageStart && 
                 ts.chainageStart <= l.chainageEnd,
        );
      } catch (e) {
        // Fallback: find any LCS with matching VCC, or create a default
        if (_cachedData!.lcsList.isEmpty) {
          // Create a default LCS record if list is empty
          lcs = LcsRecord(
            currentLcsCode: '',
            legacyLcsCode: '',
            vcc: ts.vcc,
            chainageStart: 0.0,
            chainageEnd: 0.0,
            lcsLength: 0.0,
            shortDescription: 'Unknown LCS',
          );
        } else {
          // Try to find any LCS with matching VCC
          try {
            lcs = _cachedData!.lcsList.firstWhere(
              (l) => l.vcc == ts.vcc,
            );
          } catch (e2) {
            // If no matching VCC found, use first available LCS (safe because we checked isEmpty above)
            lcs = _cachedData!.lcsList.first;
          }
        }
      }
      
      LCSStationMapping? stationMapping;
      try {
        stationMapping = _stationMappings.firstWhere(
          (s) => _normalizeLcsCode(s.lcsCode) == _normalizeLcsCode(lcs.displayCode),
        );
      } catch (e) {
        if (_stationMappings.isNotEmpty) {
          stationMapping = _stationMappings.first;
        } else {
          stationMapping = LCSStationMapping(
            lcsCode: lcs.displayCode,
            station: lcs.shortDescription,
            line: 'Unknown',
            aliases: const [],
          );
        }
      }
      
      // Create a basic TrackSection first, then enhance it
      final basicSection = TrackSection(
        lcsCode: lcs.currentLcsCode,
        legacyLcsCode: lcs.legacyLcsCode,
        legacyJnpLcsCode: '',
        roadStatus: 'Commissioned',
        operatingLineCode: _extractLineCode(stationMapping.line),
        operatingLine: stationMapping.line,
        newLongDescription: lcs.shortDescription,
        newShortDescription: lcs.shortDescription,
        vcc: ts.vcc.toStringAsFixed(0),
        thalesChainage: ts.chainageStart.toStringAsFixed(3),
        segmentId: ts.segment,
        lcsMeterageStart: ts.chainageStart - lcs.chainageStart,
        lcsMeterageEnd: ts.chainageStart - lcs.chainageStart + 100,
        track: ts.segment,
        trackSection: ts.tsId.toString(),
        physicalAssets: '',
        notes: '',
      );
      
      return EnhancedTrackSection.fromTrackSection(
        basicSection,
        stationMapping,
      );
    }).toList();
  }

  void _buildIndices() {
    _lcsToStations.clear();
    for (final mapping in _stationMappings) {
      final normalized = _normalizeLcsCode(mapping.lcsCode);
      _lcsToStations.putIfAbsent(normalized, () => []).add(mapping);
    }
  }

  String _normalizeLcsCode(String code) {
    return code.toUpperCase().replaceAll('_', '/').replaceAll('-', '/');
  }

  String _extractLineCode(String line) {
    if (line.contains('District')) return 'D';
    if (line.contains('Circle')) return 'C';
    if (line.contains('Metropolitan')) return 'M';
    if (line.contains('Hammersmith')) return 'H';
    return 'D';
  }

  /// Find LCS with partial matching - returns list of candidates
  List<LcsRecord> findLcsPartial(String partialCode) {
    if (_cachedData == null || partialCode.isEmpty) return [];
    
    final normalized = partialCode.toUpperCase().trim();
    final candidates = <LcsRecord>[];
    
    for (final lcs in _cachedData!.lcsList) {
      final legacy = lcs.legacyLcsCode.toUpperCase();
      final current = lcs.currentLcsCode.toUpperCase();
      final display = lcs.displayCode.toUpperCase();
      
      if (legacy.contains(normalized) || 
          current.contains(normalized) || 
          display.contains(normalized)) {
        candidates.add(lcs);
      }
    }
    
    // Sort by relevance (exact matches first, then starts with, then contains)
    candidates.sort((a, b) {
      final aDisplay = a.displayCode.toUpperCase();
      final bDisplay = b.displayCode.toUpperCase();
      
      final aExact = aDisplay == normalized;
      final bExact = bDisplay == normalized;
      if (aExact != bExact) return aExact ? -1 : 1;
      
      final aStarts = aDisplay.startsWith(normalized);
      final bStarts = bDisplay.startsWith(normalized);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      
      return aDisplay.compareTo(bDisplay);
    });
    
    return candidates;
  }

  /// Find nearest chainage for a given LCS and meterage
  NearestChainageResult findNearestChainage(String lcsCode, double meterage) {
    if (_cachedData == null) {
      return NearestChainageResult(
        originalMeterage: meterage,
        correctedMeterage: meterage,
        distance: 0,
        wasCorrected: false,
      );
    }
    
    final lcs = findLcsByCode(lcsCode, _cachedData!);
    if (lcs == null) {
      return NearestChainageResult(
        originalMeterage: meterage,
        correctedMeterage: meterage,
        distance: 0,
        wasCorrected: false,
      );
    }
    
    // Find all TS records for this LCS
    final tsList = _cachedData!.tsList
        .where((ts) => ts.vcc == lcs.vcc)
        .toList();
    
    if (tsList.isEmpty) {
      return NearestChainageResult(
        originalMeterage: meterage,
        correctedMeterage: meterage,
        distance: 0,
        wasCorrected: false,
      );
    }
    
    // Convert meterage to absolute chainage
    final absChainage = lcs.chainageStart + meterage;
    
    // Find nearest TS chainage
    double minDistance = double.infinity;
    double nearestChainage = absChainage;
    
    for (final ts in tsList) {
      final distance = (ts.chainageStart - absChainage).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestChainage = ts.chainageStart;
      }
    }
    
    // Convert back to meterage
    final correctedMeterage = nearestChainage - lcs.chainageStart;
    final wasCorrected = (meterage - correctedMeterage).abs() > 0.1;
    
    return NearestChainageResult(
      originalMeterage: meterage,
      correctedMeterage: correctedMeterage,
      distance: minDistance,
      wasCorrected: wasCorrected,
      nearestChainage: nearestChainage,
    );
  }

  LcsRecord? findLcsByCode(String code, LcsTsAppData data) {
    final upperCode = code.toUpperCase().trim();
    try {
      return data.lcsList.firstWhere(
        (l) =>
            l.legacyLcsCode.toUpperCase() == upperCode ||
            l.currentLcsCode.toUpperCase() == upperCode ||
            _normalizeLcsCode(l.legacyLcsCode) == _normalizeLcsCode(upperCode) ||
            _normalizeLcsCode(l.currentLcsCode) == _normalizeLcsCode(upperCode),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get comprehensive location info for a result
  LocationInfo getLocationInfo(LcsRecord lcs, double meterage, List<TsRecord> trackSections) {
      LCSStationMapping? stationMapping;
      try {
        stationMapping = _stationMappings.firstWhere(
          (s) => _normalizeLcsCode(s.lcsCode) == _normalizeLcsCode(lcs.displayCode),
        );
      } catch (e) {
        stationMapping = LCSStationMapping(
          lcsCode: lcs.displayCode,
          station: lcs.shortDescription,
          line: 'Unknown',
          aliases: const [],
        );
      }
    
    final absChainage = lcs.chainageStart + meterage;
    final tsIds = trackSections.map((ts) => ts.tsId).toList();
    
    final platforms = <String>[];
    if (_cachedData != null) {
      for (final tsId in tsIds) {
        final plats = _cachedData!.platformsByTs[tsId] ?? [];
        platforms.addAll(plats);
      }
    }
    
    return LocationInfo(
      station: stationMapping.station,
      line: stationMapping.line,
      lcsCode: lcs.displayCode,
      chainage: absChainage,
      meterage: meterage,
      trackSections: tsIds,
      platforms: platforms.toSet().toList(),
    );
  }

  List<TsRecord> findTrackSections({
    required LcsRecord lcs,
    required double startMeterage,
    required double endMeterage,
    required LcsTsAppData data,
  }) {
    if (startMeterage > endMeterage) {
      final tmp = startMeterage;
      startMeterage = endMeterage;
      endMeterage = tmp;
    }

    final absStart = lcs.chainageStart + startMeterage;
    final absEnd = lcs.chainageStart + endMeterage;

    final matching = data.tsList
        .where((ts) =>
            ts.vcc == lcs.vcc &&
            ts.chainageStart >= absStart &&
            ts.chainageStart <= absEnd)
        .toList()
      ..sort((a, b) => a.chainageStart.compareTo(b.chainageStart));

    return matching;
  }

  LcsTsAppData? get cachedData => _cachedData;
  List<LCSStationMapping> get stationMappings => _stationMappings;
  List<EnhancedTrackSection> get enhancedTrackSections => _enhancedTrackSections;
}

