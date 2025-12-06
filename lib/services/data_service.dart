// services/data_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/track_data.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<TrackSection> _trackSections = [];
  List<Location> _locations = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<TrackSection> getTrackSections() => List.unmodifiable(_trackSections);
  List<Location> getLocations() => List.unmodifiable(_locations);

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadTrackSections();
      await _loadLocations();
      _initialized = true;
    } catch (e) {
      // If loading from assets fails, use sample data
      _trackSections = _getSampleTrackSections();
      _locations = _getSampleLocations();
      _initialized = true;
    }
  }

  Future<void> _loadTrackSections() async {
    try {
      final String data = await rootBundle.loadString('assets/data/track_data.json');
      final List<dynamic> jsonData = json.decode(data);
      _trackSections = jsonData.map((json) => TrackSection.fromJson(json)).toList();
    } catch (e) {
      // Use sample data if file doesn't exist
      _trackSections = _getSampleTrackSections();
    }
  }

  Future<void> _loadLocations() async {
    try {
      final String data = await rootBundle.loadString('assets/data/station_coordinates.json');
      final List<dynamic> jsonData = json.decode(data);
      _locations = jsonData.map((json) => Location.fromJson(json)).toList();
    } catch (e) {
      // Use sample data if file doesn't exist
      _locations = _getSampleLocations();
    }
  }

  QueryResult searchByMeterage(double meterage, {double radius = 100}) {
    // Find sections containing the meterage
    final containingSections = _trackSections
        .where((section) => section.isWithinMeterage(meterage))
        .toList();

    TrackSection? nearestSection;
    if (containingSections.isNotEmpty) {
      nearestSection = containingSections.first;
    } else {
      // Find nearest section
      double minDistance = double.infinity;
      for (var section in _trackSections) {
        double distance;
        if (meterage < section.lcsMeterageStart) {
          distance = section.lcsMeterageStart - meterage;
        } else if (meterage > section.lcsMeterageEnd) {
          distance = meterage - section.lcsMeterageEnd;
        } else {
          distance = 0;
        }

        if (distance < minDistance) {
          minDistance = distance;
          nearestSection = section;
        }
      }
    }

    // Find nearest location
    Location? nearestLocation;
    double minLocationDistance = double.infinity;
    for (var location in _locations) {
      final distance = (location.referenceMeterage - meterage).abs();
      if (distance < minLocationDistance) {
        minLocationDistance = distance;
        nearestLocation = location;
      }
    }

    return QueryResult(
      nearestSection: nearestSection,
      nearestLocation: nearestLocation,
      inputMeterage: meterage,
      distanceToNearestLocation: minLocationDistance,
    );
  }

  QueryResult searchByLcsCode(String lcsCode) {
    // Find exact match
    TrackSection? section = _trackSections.firstWhere(
      (s) => s.lcsCode == lcsCode,
      orElse: () => _trackSections.firstWhere(
        (s) => s.lcsCode.contains(lcsCode) || lcsCode.contains(s.lcsCode),
        orElse: () => _trackSections.firstWhere(
          (s) => s.legacyLcsCode == lcsCode || s.legacyJnpLcsCode == lcsCode,
          orElse: () => TrackSection(
            lcsCode: '',
            legacyLcsCode: '',
            legacyJnpLcsCode: '',
            roadStatus: '',
            operatingLineCode: '',
            operatingLine: '',
            newLongDescription: '',
            newShortDescription: '',
            vcc: '',
            thalesChainage: '',
            segmentId: '',
            lcsMeterageStart: 0,
            lcsMeterageEnd: 0,
            track: '',
            trackSection: '',
          ),
        ),
      ),
    );

    if (section.lcsCode.isEmpty) {
      return QueryResult(
        inputMeterage: 0,
        inputLcsCode: lcsCode,
      );
    }

    // Find nearest location for this section
    final midMeterage = section.midpointMeterage;
    Location? nearestLocation;
    double minDistance = double.infinity;
    for (var location in _locations) {
      final distance = (location.referenceMeterage - midMeterage).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestLocation = location;
      }
    }

    return QueryResult(
      nearestSection: section,
      nearestLocation: nearestLocation,
      inputMeterage: midMeterage,
      distanceToNearestLocation: minDistance,
      inputLcsCode: lcsCode,
    );
  }

  List<TrackSection> searchSectionsByLine(String line) {
    return _trackSections
        .where((section) =>
            section.operatingLine.toLowerCase().contains(line.toLowerCase()))
        .toList();
  }

  List<Location> searchLocationsByName(String name) {
    return _locations
        .where((location) =>
            location.name.toLowerCase().contains(name.toLowerCase()))
        .toList();
  }

  TrackSectionStats getStatistics() {
    final sectionsByLine = <String, int>{};
    final lengthByLine = <String, double>{};

    for (var section in _trackSections) {
      final line = section.operatingLine;
      sectionsByLine[line] = (sectionsByLine[line] ?? 0) + 1;
      lengthByLine[line] = (lengthByLine[line] ?? 0) + section.length;
    }

    return TrackSectionStats(
      totalSections: _trackSections.length,
      totalLines: sectionsByLine.length,
      totalTrackLength: _trackSections.fold(0, (sum, section) => sum + section.length),
      sectionsByLine: sectionsByLine,
      lengthByLine: lengthByLine,
    );
  }

  List<TrackSection> _getSampleTrackSections() {
    return [
      TrackSection(
        lcsCode: 'M189-M-RD21',
        legacyLcsCode: 'M189',
        legacyJnpLcsCode: 'M189-JNP',
        roadStatus: 'Active',
        operatingLineCode: 'MET',
        operatingLine: 'Metropolitan Line',
        newLongDescription: 'Metropolitan Line - Royal Oak to Paddington',
        newShortDescription: 'Royal Oak - Paddington',
        vcc: 'VCC-M-01',
        thalesChainage: 'TC-15000',
        segmentId: 'SEG-M-189',
        lcsMeterageStart: 15000.0,
        lcsMeterageEnd: 15250.0,
        track: 'EB',
        trackSection: 'RD21',
        physicalAssets: 'Signals, Points',
        notes: 'Main line section',
      ),
      TrackSection(
        lcsCode: 'D011-D-UP01',
        legacyLcsCode: 'D011',
        legacyJnpLcsCode: 'D011-JNP',
        roadStatus: 'Active',
        operatingLineCode: 'DIS',
        operatingLine: 'District Line',
        newLongDescription: 'District Line - Upminster Station',
        newShortDescription: 'Upminster Station',
        vcc: 'VCC-D-01',
        thalesChainage: 'TC-10000',
        segmentId: 'SEG-D-011',
        lcsMeterageStart: 10000.0,
        lcsMeterageEnd: 10150.0,
        track: 'EB',
        trackSection: 'UP01',
        physicalAssets: 'Platform, Signals',
        notes: 'Terminal station',
      ),
      TrackSection(
        lcsCode: 'C055-C-BST01',
        legacyLcsCode: 'C055',
        legacyJnpLcsCode: 'C055-JNP',
        roadStatus: 'Active',
        operatingLineCode: 'CIR',
        operatingLine: 'Circle Line',
        newLongDescription: 'Circle Line - Baker Street Station',
        newShortDescription: 'Baker Street',
        vcc: 'VCC-C-01',
        thalesChainage: 'TC-20000',
        segmentId: 'SEG-C-055',
        lcsMeterageStart: 20000.0,
        lcsMeterageEnd: 20300.0,
        track: 'IR',
        trackSection: 'BST01',
        physicalAssets: 'Platform, Interchange',
        notes: 'Major interchange',
      ),
    ];
  }

  List<Location> _getSampleLocations() {
    return [
      const Location(
        code: 'M189',
        name: 'Royal Oak',
        line: 'Metropolitan Line',
        referenceMeterage: 15125.0,
        latitude: 51.5191,
        longitude: -0.1880,
        zone: 2,
      ),
      const Location(
        code: 'D011',
        name: 'Upminster',
        line: 'District Line',
        referenceMeterage: 10075.0,
        latitude: 51.5590,
        longitude: 0.2509,
        zone: 6,
      ),
      const Location(
        code: 'C055',
        name: 'Baker Street',
        line: 'Circle Line',
        referenceMeterage: 20150.0,
        latitude: 51.5226,
        longitude: -0.1571,
        zone: 1,
      ),
    ];
  }
}
