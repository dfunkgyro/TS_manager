// services/data_persistence_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enhanced_track_data.dart';
import '../models/track_data.dart';

class DataPersistenceService {
  static final DataPersistenceService _instance = DataPersistenceService._internal();
  factory DataPersistenceService() => _instance;
  DataPersistenceService._internal();

  static const String _stationMappingsKey = 'custom_station_mappings';
  static const String _trackSectionsKey = 'custom_track_sections';

  /// Save custom station mappings
  Future<void> saveStationMappings(List<LCSStationMapping> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = mappings.map((m) => m.toJson()).toList();
    await prefs.setString(_stationMappingsKey, json.encode(jsonList));
  }

  /// Load custom station mappings
  Future<List<LCSStationMapping>> loadStationMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_stationMappingsKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => LCSStationMapping.fromJson(json)).toList();
  }

  /// Add or update a station mapping
  Future<void> addOrUpdateStationMapping(LCSStationMapping mapping) async {
    final existing = await loadStationMappings();
    final index = existing.indexWhere((m) => m.lcsCode == mapping.lcsCode);

    if (index >= 0) {
      existing[index] = mapping;
    } else {
      existing.add(mapping);
    }

    await saveStationMappings(existing);
  }

  /// Delete a station mapping
  Future<void> deleteStationMapping(String lcsCode) async {
    final existing = await loadStationMappings();
    existing.removeWhere((m) => m.lcsCode == lcsCode);
    await saveStationMappings(existing);
  }

  /// Save custom track sections
  Future<void> saveTrackSections(List<TrackSection> sections) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sections.map((s) => s.toJson()).toList();
    await prefs.setString(_trackSectionsKey, json.encode(jsonList));
  }

  /// Load custom track sections
  Future<List<TrackSection>> loadTrackSections() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_trackSectionsKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => TrackSection.fromJson(json)).toList();
  }

  /// Clear all custom data
  Future<void> clearAllCustomData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stationMappingsKey);
    await prefs.remove(_trackSectionsKey);
  }

  /// Export data to XML string
  String exportToXml(List<LCSStationMapping> mappings) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<LCS_Map>');
    buffer.writeln('    <!-- Custom LCS Mappings -->');

    for (var mapping in mappings) {
      buffer.writeln('    <Entry>');
      buffer.writeln('        <LCS_Code>${mapping.lcsCode}</LCS_Code>');
      buffer.writeln('        <Station>${mapping.station}</Station>');
      buffer.writeln('        <Line>${mapping.line}</Line>');
      if (mapping.branch != null) {
        buffer.writeln('        <Branch>${mapping.branch}</Branch>');
      }
      if (mapping.latitude != null) {
        buffer.writeln('        <Latitude>${mapping.latitude}</Latitude>');
      }
      if (mapping.longitude != null) {
        buffer.writeln('        <Longitude>${mapping.longitude}</Longitude>');
      }
      if (mapping.zone != null) {
        buffer.writeln('        <Zone>${mapping.zone}</Zone>');
      }
      buffer.writeln('    </Entry>');
    }

    buffer.writeln('</LCS_Map>');
    return buffer.toString();
  }

  /// Export track sections to JSON
  String exportTrackSectionsToJson(List<TrackSection> sections) {
    final data = {
      'metadata': {
        'version': '3.0',
        'exported_at': DateTime.now().toIso8601String(),
        'data_source': 'Track Sections Manager - Custom Data',
      },
      'track_sections': sections.map((s) => s.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
