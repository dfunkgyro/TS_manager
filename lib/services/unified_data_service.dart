import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/models/enhanced_track_data.dart' hide EnhancedTrackSection;
import 'package:track_sections_manager/models/enhanced_lcs_ts_models.dart' show EnhancedTrackSection, LocationInfo;
import 'package:track_sections_manager/models/track_data.dart';

/// Unified data service that loads and interconnects ALL data sources
class UnifiedDataService {
  static UnifiedDataService? _instance;
  
  // Core data
  LcsTsAppData? _lcsTsData;
  List<LCSStationMapping> _stationMappings = [];
  List<EnhancedTrackSection> _comprehensiveTrackSections = [];
  List<Location> _locations = [];
  
  // User-added data (persisted)
  List<LCSStationMapping> _userStationMappings = [];
  List<EnhancedTrackSection> _userTrackSections = [];
  Map<String, List<int>> _userLcsToTrackSections = {}; // LCS code -> track section IDs
  
  // Indices for fast lookup
  Map<String, LcsRecord> _lcsByCode = {}; // All variations of LCS code -> LcsRecord
  Map<String, List<LCSStationMapping>> _stationsByLcs = {};
  Map<int, List<String>> _platformsByTs = {};
  Map<String, List<EnhancedTrackSection>> _sectionsByLcs = {};
  Map<String, List<EnhancedTrackSection>> _sectionsByLine = {};
  Map<int, EnhancedTrackSection> _sectionsByTsId = {};
  Map<String, List<String>> _lcsCodesByLine = {};
  
  bool _isLoaded = false;

  UnifiedDataService._();

  factory UnifiedDataService() {
    _instance ??= UnifiedDataService._();
    return _instance!;
  }

  bool get isLoaded => _isLoaded;
  List<LcsRecord> get allLcsRecords => _lcsTsData?.lcsList ?? [];
  List<LCSStationMapping> get allStationMappings => [..._stationMappings, ..._userStationMappings];
  List<EnhancedTrackSection> get allTrackSections => [..._comprehensiveTrackSections, ..._userTrackSections];
  List<String> get allLcsCodes => _lcsByCode.keys.toList()..sort();
  List<String> get allLines => _lcsCodesByLine.keys.toList()..sort();
  List<String> get allStations => allStationMappings.map((s) => s.station).toSet().toList()..sort();

  /// Load all data sources and build indices
  Future<void> loadAllData() async {
    if (_isLoaded) return;

    try {
      await Future.wait([
        _loadLcsTsData(),
        _loadStationMappings(),
        _loadComprehensiveTrackSections(),
        _loadLocations(),
        _loadUserData(),
      ]);
      
      _buildIndices();
      _isLoaded = true;
      print('✓ Unified data service loaded: ${_lcsTsData?.lcsList.length ?? 0} LCS, ${_comprehensiveTrackSections.length} track sections, ${_stationMappings.length} stations');
    } catch (e) {
      print('Error loading unified data: $e');
      rethrow;
    }
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

      _lcsTsData = LcsTsAppData(
        lcsList: lcsList,
        tsList: tsList,
        platformList: platformList,
        platformsByTs: platformsByTs,
      );
      
      _platformsByTs = platformsByTs;
    } catch (e) {
      print('Error loading LCS/TS data: $e');
    }
  }

  Future<void> _loadStationMappings() async {
    try {
      final data = await rootBundle.loadString('assets/data/lcs_mappings.xml');
      final document = XmlDocument.parse(data);
      
      _stationMappings = document.findAllElements('Entry').map((element) {
        final lcsCode = element.findElements('LCS_Code').first.innerText.trim();
        final station = element.findElements('Station').first.innerText.trim();
        final line = element.findElements('Line').first.innerText.trim();
        
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

  Future<void> _loadComprehensiveTrackSections() async {
    try {
      final data = await rootBundle.loadString('assets/data/comprehensive_track_sections.json');
      final json = jsonDecode(data) as Map<String, dynamic>;
      final sectionsJson = json['track_sections'] as List<dynamic>? ?? [];
      
      _comprehensiveTrackSections = sectionsJson
          .map((e) => EnhancedTrackSection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading comprehensive track sections: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final data = await rootBundle.loadString('assets/data/station_coordinates.json');
      final json = jsonDecode(data) as List<dynamic>;
      _locations = json.map((e) => Location.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Warning: Could not load locations: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load user station mappings
      final userMappingsJson = prefs.getString('user_station_mappings');
      if (userMappingsJson != null) {
        final List<dynamic> jsonList = jsonDecode(userMappingsJson);
        _userStationMappings = jsonList
            .map((e) => LCSStationMapping.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      
      // Load user track sections
      final userSectionsJson = prefs.getString('user_track_sections');
      if (userSectionsJson != null) {
        final List<dynamic> jsonList = jsonDecode(userSectionsJson);
        _userTrackSections = jsonList
            .map((e) => EnhancedTrackSection.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      
      // Load user LCS to track sections mappings
      final userLcsTsJson = prefs.getString('user_lcs_to_track_sections');
      if (userLcsTsJson != null) {
        _userLcsToTrackSections = Map<String, List<int>>.from(
          jsonDecode(userLcsTsJson) as Map,
        );
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _buildIndices() {
    _lcsByCode.clear();
    _stationsByLcs.clear();
    _sectionsByLcs.clear();
    _sectionsByLine.clear();
    _sectionsByTsId.clear();
    _lcsCodesByLine.clear();

    // Index LCS records by all code variations
    if (_lcsTsData != null) {
      for (final lcs in _lcsTsData!.lcsList) {
        final codes = [
          lcs.currentLcsCode.toUpperCase(),
          lcs.legacyLcsCode.toUpperCase(),
          _normalizeLcsCode(lcs.currentLcsCode),
          _normalizeLcsCode(lcs.legacyLcsCode),
        ];
        for (final code in codes) {
          if (code.isNotEmpty) {
            _lcsByCode[code] = lcs;
          }
        }
      }
    }

    // Index station mappings by LCS code
    for (final mapping in allStationMappings) {
      final normalized = _normalizeLcsCode(mapping.lcsCode);
      _stationsByLcs.putIfAbsent(normalized, () => []).add(mapping);
      
      // Index by line
      _lcsCodesByLine.putIfAbsent(mapping.line, () => []).add(mapping.lcsCode);
    }

    // Index track sections by LCS code, line, and TS ID
    for (final section in allTrackSections) {
      final lcsCodes = [
        section.currentLcsCode,
        section.legacyLcsCode,
        _normalizeLcsCode(section.currentLcsCode),
        _normalizeLcsCode(section.legacyLcsCode),
      ];
      
      for (final code in lcsCodes) {
        if (code.isNotEmpty) {
          _sectionsByLcs.putIfAbsent(code, () => []).add(section);
        }
      }
      
      _sectionsByLine.putIfAbsent(section.operatingLine, () => []).add(section);
      
      final tsId = section.trackSectionId;
      if (tsId > 0) {
        _sectionsByTsId[tsId] = section;
      }
    }

    // Add user-defined LCS to track sections mappings
    for (final entry in _userLcsToTrackSections.entries) {
      final lcsCode = entry.key;
      final tsIds = entry.value;
      for (final tsId in tsIds) {
        final section = _sectionsByTsId[tsId];
        if (section != null) {
          _sectionsByLcs.putIfAbsent(lcsCode, () => []).add(section);
        }
      }
    }
  }

  String _normalizeLcsCode(String code) {
    return code.toUpperCase().replaceAll('_', '/').replaceAll('-', '/').trim();
  }

  /// Find LCS by code (searches all variations)
  LcsRecord? findLcsByCode(String code) {
    if (!_isLoaded || _lcsTsData == null) return null;
    
    final normalized = _normalizeLcsCode(code);
    try {
      return _lcsByCode[normalized] ?? 
             _lcsByCode[code.toUpperCase()] ??
             _lcsTsData!.lcsList.firstWhere(
               (l) => _normalizeLcsCode(l.currentLcsCode) == normalized ||
                      _normalizeLcsCode(l.legacyLcsCode) == normalized ||
                      l.currentLcsCode.toUpperCase() == code.toUpperCase() ||
                      l.legacyLcsCode.toUpperCase() == code.toUpperCase(),
             );
    } catch (e) {
      return null;
    }
  }

  /// Find all LCS codes matching partial input
  List<LcsRecord> findLcsPartial(String partialCode) {
    if (!_isLoaded || _lcsTsData == null) return [];
    
    final normalized = partialCode.toUpperCase().trim();
    if (normalized.isEmpty) return [];
    
    final candidates = <LcsRecord>[];
    final seen = <String>{};
    
    for (final lcs in _lcsTsData!.lcsList) {
      final codes = [
        lcs.currentLcsCode.toUpperCase(),
        lcs.legacyLcsCode.toUpperCase(),
        _normalizeLcsCode(lcs.currentLcsCode),
        _normalizeLcsCode(lcs.legacyLcsCode),
      ];
      
      for (final code in codes) {
        if (code.contains(normalized) && !seen.contains(code)) {
          candidates.add(lcs);
          seen.add(code);
          break;
        }
      }
    }
    
    // Sort by relevance
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

  /// Get station mapping for LCS code
  LCSStationMapping? getStationMapping(String lcsCode) {
    final normalized = _normalizeLcsCode(lcsCode);
    final mappings = _stationsByLcs[normalized];
    return mappings?.isNotEmpty == true ? mappings!.first : null;
  }

  /// Get all track sections for an LCS code
  List<EnhancedTrackSection> getTrackSectionsByLcs(String lcsCode) {
    final normalized = _normalizeLcsCode(lcsCode);
    return _sectionsByLcs[normalized] ?? 
           _sectionsByLcs[lcsCode.toUpperCase()] ?? 
           [];
  }

  /// Get all track sections for a line
  List<EnhancedTrackSection> getTrackSectionsByLine(String line) {
    return _sectionsByLine[line] ?? [];
  }

  /// Get track sections by meterage range
  List<TsRecord> findTrackSectionsByMeterage({
    required LcsRecord lcs,
    required double startMeterage,
    required double endMeterage,
  }) {
    if (!_isLoaded || _lcsTsData == null) return [];
    
    if (startMeterage > endMeterage) {
      final tmp = startMeterage;
      startMeterage = endMeterage;
      endMeterage = tmp;
    }

    final absStart = lcs.chainageStart + startMeterage;
    final absEnd = lcs.chainageStart + endMeterage;

    final matching = _lcsTsData!.tsList
        .where((ts) =>
            ts.vcc == lcs.vcc &&
            ts.chainageStart >= absStart &&
            ts.chainageStart <= absEnd)
        .toList()
      ..sort((a, b) => a.chainageStart.compareTo(b.chainageStart));

    return matching;
  }

  /// Get platforms for track section ID
  List<String> getPlatformsForTrackSection(int tsId) {
    return _platformsByTs[tsId] ?? [];
  }

  /// Get comprehensive location info
  LocationInfo getLocationInfo(LcsRecord lcs, double meterage, List<TsRecord> trackSections) {
    final stationMapping = getStationMapping(lcs.displayCode);
    final absChainage = lcs.chainageStart + meterage;
    final tsIds = trackSections.map((ts) => ts.tsId).toList();
    
    final platforms = <String>[];
    for (final tsId in tsIds) {
      platforms.addAll(getPlatformsForTrackSection(tsId));
    }
    
    return LocationInfo(
      station: stationMapping?.station ?? lcs.shortDescription,
      line: stationMapping?.line ?? 'Unknown',
      lcsCode: lcs.displayCode,
      chainage: absChainage,
      meterage: meterage,
      trackSections: tsIds,
      platforms: platforms.toSet().toList(),
    );
  }

  /// Add user-defined station mapping
  Future<void> addUserStationMapping(LCSStationMapping mapping) async {
    _userStationMappings.add(mapping);
    _buildIndices();
    await _saveUserData();
  }

  /// Add user-defined track section
  Future<void> addUserTrackSection(EnhancedTrackSection section) async {
    _userTrackSections.add(section);
    _buildIndices();
    await _saveUserData();
  }

  /// Remove user-defined track section
  Future<void> removeUserTrackSection(String trackSectionId) async {
    _userTrackSections.removeWhere((ts) => ts.trackSection == trackSectionId);
    _buildIndices();
    await _saveUserData();
  }

  /// Link LCS code to track section IDs
  Future<void> linkLcsToTrackSections(String lcsCode, List<int> tsIds) async {
    _userLcsToTrackSections[lcsCode] = tsIds;
    _buildIndices();
    await _saveUserData();
  }

  Future<void> _saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('user_station_mappings', 
        jsonEncode(_userStationMappings.map((m) => m.toJson()).toList()));
      
      await prefs.setString('user_track_sections',
        jsonEncode(_userTrackSections.map((s) => s.toJson()).toList()));
      
      await prefs.setString('user_lcs_to_track_sections',
        jsonEncode(_userLcsToTrackSections));
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  /// Export all data to JSON
  Map<String, dynamic> exportAllData() {
    return {
      'metadata': {
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0',
      },
      'lcs_records': _lcsTsData?.lcsList.map((l) => {
        'currentLcsCode': l.currentLcsCode,
        'legacyLcsCode': l.legacyLcsCode,
        'vcc': l.vcc,
        'chainageStart': l.chainageStart,
        'chainageEnd': l.chainageEnd,
        'lcsLength': l.lcsLength,
        'shortDescription': l.shortDescription,
      }).toList() ?? [],
      'track_sections': allTrackSections.map((s) => s.toJson()).toList(),
      'station_mappings': allStationMappings.map((m) => m.toJson()).toList(),
      'user_lcs_to_track_sections': _userLcsToTrackSections,
    };
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      // Import user station mappings
      if (data.containsKey('station_mappings')) {
        final mappingsJson = data['station_mappings'] as List<dynamic>;
        for (final mappingData in mappingsJson) {
          final mapping = LCSStationMapping.fromJson(mappingData as Map<String, dynamic>);
          if (!_userStationMappings.any((m) => m.lcsCode == mapping.lcsCode)) {
            _userStationMappings.add(mapping);
          }
        }
      }

      // Import user track sections
      if (data.containsKey('track_sections')) {
        final sectionsJson = data['track_sections'] as List<dynamic>;
        for (final sectionData in sectionsJson) {
          final section = EnhancedTrackSection.fromJson(sectionData as Map<String, dynamic>);
          if (!_userTrackSections.any((s) => s.trackSectionId == section.trackSectionId)) {
            _userTrackSections.add(section);
          }
        }
      }

      // Import user LCS to track sections mappings
      if (data.containsKey('user_lcs_to_track_sections')) {
        final mappingsData = data['user_lcs_to_track_sections'] as Map<String, dynamic>;
        for (final entry in mappingsData.entries) {
          final lcsCode = entry.key;
          final tsIds = (entry.value as List).cast<int>();
          _userLcsToTrackSections[lcsCode] = tsIds;
        }
      }

      // Rebuild indices and save
      _buildIndices();
      await _saveUserData();

      print('✓ Data imported successfully');
    } catch (e) {
      print('Error importing data: $e');
      rethrow;
    }
  }

  /// Get all data including user additions
  Map<String, dynamic> getAllDataWithUserAdditions() {
    return {
      'station_mappings': allStationMappings.map((m) => m.toJson()).toList(),
      'track_sections': allTrackSections.map((s) => s.toJson()).toList(),
      'user_lcs_to_track_sections': _userLcsToTrackSections,
      'lcs_codes': allLcsCodes,
      'lines': allLines,
      'stations': allStations,
    };
  }

  /// Clear all user data
  Future<void> clearUserData() async {
    _userStationMappings.clear();
    _userTrackSections.clear();
    _userLcsToTrackSections.clear();
    _buildIndices();
    await _saveUserData();
  }
}

