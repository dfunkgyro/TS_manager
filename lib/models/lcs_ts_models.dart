/// Data models for LCS, TS, and Platform records

class LcsRecord {
  final String currentLcsCode;
  final String legacyLcsCode;
  final double vcc;
  final double chainageStart;
  final double chainageEnd;
  final double lcsLength;
  final String shortDescription;

  LcsRecord({
    required this.currentLcsCode,
    required this.legacyLcsCode,
    required this.vcc,
    required this.chainageStart,
    required this.chainageEnd,
    required this.lcsLength,
    required this.shortDescription,
  });

  factory LcsRecord.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    return LcsRecord(
      currentLcsCode: (json['currentLcsCode'] ?? '').toString(),
      legacyLcsCode: (json['legacyLcsCode'] ?? '').toString(),
      vcc: _toDouble(json['vcc']),
      chainageStart: _toDouble(json['chainageStart']),
      chainageEnd: _toDouble(json['chainageEnd']),
      lcsLength: _toDouble(json['lcsLength']),
      shortDescription: (json['shortDescription'] ?? '').toString(),
    );
  }

  String get displayCode => legacyLcsCode.isNotEmpty ? legacyLcsCode : currentLcsCode;
}

class TsRecord {
  final int tsId;
  final String segment;
  final double chainageStart;
  final double vcc;

  TsRecord({
    required this.tsId,
    required this.segment,
    required this.chainageStart,
    required this.vcc,
  });

  factory TsRecord.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) =>
        v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

    int _toInt(dynamic v) =>
        v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

    return TsRecord(
      tsId: _toInt(json['tsId']),
      segment: (json['segment'] ?? '').toString(),
      chainageStart: _toDouble(json['chainageStart']),
      vcc: _toDouble(json['vcc']),
    );
  }
}

class PlatformRecord {
  final String platform;
  final List<int> trackSections;

  PlatformRecord({
    required this.platform,
    required this.trackSections,
  });

  factory PlatformRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['trackSections'] as List<dynamic>? ?? [];
    final ts = raw
        .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()) ?? 0)
        .where((v) => v != 0)
        .toList();

    return PlatformRecord(
      platform: (json['platform'] ?? '').toString(),
      trackSections: ts,
    );
  }
}

class LcsTsAppData {
  final List<LcsRecord> lcsList;
  final List<TsRecord> tsList;
  final List<PlatformRecord> platformList;
  final Map<int, List<String>> platformsByTs; // tsId -> platforms

  LcsTsAppData({
    required this.lcsList,
    required this.tsList,
    required this.platformList,
    required this.platformsByTs,
  });
}

