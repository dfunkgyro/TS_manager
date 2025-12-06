import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:track_sections_manager/models/lcs_ts_models.dart';

/// Service to load and manage LCS, TS, and Platform data
class LcsTsService {
  static LcsTsService? _instance;
  LcsTsAppData? _cachedData;

  LcsTsService._();

  factory LcsTsService() {
    _instance ??= LcsTsService._();
    return _instance!;
  }

  /// Load all data from JSON assets
  Future<LcsTsAppData> loadAppData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      final lcsRaw = await rootBundle.loadString('assets/data/lcs.json');
      final tsRaw = await rootBundle.loadString('assets/data/ts.json');
      
      // Platform data is optional
      List<PlatformRecord> platformList = [];
      try {
        final platRaw = await rootBundle.loadString('assets/data/platform_ts.json');
        final platJson = jsonDecode(platRaw) as List<dynamic>;
        platformList = platJson
            .map((e) => PlatformRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Platform data not available, continue without it
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

      // Build reverse index TS -> platforms
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

      return _cachedData!;
    } catch (e) {
      throw Exception('Failed to load LCS/TS data: $e');
    }
  }

  /// Find LCS by code (legacy or current)
  LcsRecord? findLcsByCode(String code, LcsTsAppData data) {
    final upperCode = code.toUpperCase().trim();
    try {
      return data.lcsList.firstWhere(
        (l) =>
            l.legacyLcsCode.toUpperCase() == upperCode ||
            l.currentLcsCode.toUpperCase() == upperCode,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find track sections matching LCS and meterage range
  List<TsRecord> findTrackSections({
    required LcsRecord lcs,
    required double startMeterage,
    required double endMeterage,
    required LcsTsAppData data,
  }) {
    // Ensure start <= end
    if (startMeterage > endMeterage) {
      final tmp = startMeterage;
      startMeterage = endMeterage;
      endMeterage = tmp;
    }

    // Convert meterage to absolute chainage
    final absStart = lcs.chainageStart + startMeterage;
    final absEnd = lcs.chainageStart + endMeterage;

    // Filter TS by VCC and chainage range
    final matching = data.tsList
        .where((ts) =>
            ts.vcc == lcs.vcc &&
            ts.chainageStart >= absStart &&
            ts.chainageStart <= absEnd)
        .toList()
      ..sort((a, b) => a.chainageStart.compareTo(b.chainageStart));

    return matching;
  }

  /// Clear cached data (useful for reloading)
  void clearCache() {
    _cachedData = null;
  }
}

