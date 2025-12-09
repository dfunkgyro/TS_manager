// services/batch_operation_service.dart
import 'package:flutter/foundation.dart';
import '../models/batch_models.dart';
import '../models/track_data.dart';
import 'supabase_service.dart';
import 'data_persistence_service.dart';

/// Service for handling batch operations
class BatchOperationService {
  static final BatchOperationService _instance = BatchOperationService._internal();
  factory BatchOperationService() => _instance;
  BatchOperationService._internal();

  final SupabaseService _supabase = SupabaseService();
  final DataPersistenceService _persistence = DataPersistenceService();

  /// Generate track sections between start and end
  /// Returns a list of track section data with interpolated values
  List<Map<String, dynamic>> generateTrackSections({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
    required String lcsCode,
    required String operatingLine,
    required String roadDirection,
    String? station,
    String? vcc,
    String? legacyLcsCode,
  }) {
    // Determine direction (increasing or decreasing)
    final isIncreasing = endTrackSection > startTrackSection;
    final totalSections = (endTrackSection - startTrackSection).abs() + 1;

    if (totalSections <= 0) {
      debugPrint('Error: Invalid track section range');
      return [];
    }

    // Calculate chainage increment per section
    final totalChainageChange = endChainage - startChainage;
    final chainageIncrement = totalChainageChange / (totalSections - 1);

    final generatedSections = <Map<String, dynamic>>[];

    for (int i = 0; i < totalSections; i++) {
      final trackSectionNumber = isIncreasing
          ? startTrackSection + i
          : startTrackSection - i;

      final chainage = startChainage + (chainageIncrement * i);

      // Calculate meterage from LCS code
      // For now, we'll use chainage as meterage
      // In real implementation, this would calculate based on LCS code position
      final lcsMeterage = chainage;

      final trackSectionData = {
        'track_section_number': trackSectionNumber,
        'lcs_code': lcsCode,
        'legacy_lcs_code': legacyLcsCode,
        'operating_line': operatingLine,
        'operating_line_code': _getLineCode(operatingLine),
        'road_direction': roadDirection,
        'road_status': 'Active',
        'station': station,
        'vcc': vcc,
        'thales_chainage': chainage,
        'lcs_meterage': lcsMeterage,
        'lcs_meterage_end': lcsMeterage + chainageIncrement.abs(),
        'length_meters': chainageIncrement.abs(),
        'track': roadDirection,
        'data_source': 'batch',
        'verified': false,
      };

      generatedSections.add(trackSectionData);
    }

    debugPrint('Generated $totalSections track sections from $startTrackSection to $endTrackSection');
    return generatedSections;
  }

  /// Check for conflicts with existing track sections
  /// Returns a map of track section number to conflict information
  Future<Map<int, ConflictInfo>> checkConflicts({
    required List<Map<String, dynamic>> generatedSections,
    required String operatingLine,
    required String roadDirection,
    required List<TrackSection> existingTrackSections,
  }) async {
    final conflicts = <int, ConflictInfo>{};

    for (final section in generatedSections) {
      final trackSectionNumber = section['track_section_number'] as int;
      final proposedChainage = section['thales_chainage'] as double;
      final proposedMeterage = section['lcs_meterage'] as double;

      // Check if track section already exists in local data
      final existingSection = existingTrackSections.firstWhere(
        (ts) =>
            ts.trackSection == trackSectionNumber.toString() &&
            ts.operatingLine == operatingLine,
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
          physicalAssets: '',
          notes: '',
        ),
      );

      if (existingSection.lcsCode.isNotEmpty) {
        // Found a conflict
        final existingChainage = double.tryParse(existingSection.thalesChainage) ?? 0;
        final existingMeterage = existingSection.lcsMeterageStart;

        conflicts[trackSectionNumber] = ConflictInfo(
          trackSectionNumber: trackSectionNumber,
          proposedChainage: proposedChainage,
          proposedMeterage: proposedMeterage,
          existingChainage: existingChainage,
          existingMeterage: existingMeterage,
          existingLcsCode: existingSection.lcsCode,
          existingStation: existingSection.newShortDescription,
          conflictType: 'duplicate_number',
        );
      }

      // Also check Supabase if initialized
      if (_supabase.isInitialized) {
        final supabaseConflict = await _supabase.checkTrackSectionConflict(
          trackSectionNumber,
          operatingLine,
          roadDirection,
        );

        if (supabaseConflict != null && !conflicts.containsKey(trackSectionNumber)) {
          conflicts[trackSectionNumber] = ConflictInfo.fromExisting(
            trackSectionNumber: trackSectionNumber,
            proposedChainage: proposedChainage,
            proposedMeterage: proposedMeterage,
            existingData: supabaseConflict,
          );
        }
      }
    }

    if (conflicts.isNotEmpty) {
      debugPrint('Found ${conflicts.length} conflicts');
    }

    return conflicts;
  }

  /// Execute batch operation
  /// Returns the batch operation ID if successful
  Future<String?> executeBatchOperation({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
    required String lcsCode,
    required String operatingLine,
    required String roadDirection,
    String? station,
    String? vcc,
    String? legacyLcsCode,
    required List<TrackSection> existingTrackSections,
    String? conflictResolution, // 'keep_existing', 'replace_all', 'skip_conflicts'
  }) async {
    try {
      // Generate track sections
      final generatedSections = generateTrackSections(
        startTrackSection: startTrackSection,
        endTrackSection: endTrackSection,
        startChainage: startChainage,
        endChainage: endChainage,
        lcsCode: lcsCode,
        operatingLine: operatingLine,
        roadDirection: roadDirection,
        station: station,
        vcc: vcc,
        legacyLcsCode: legacyLcsCode,
      );

      if (generatedSections.isEmpty) {
        debugPrint('Error: No track sections generated');
        return null;
      }

      // Check for conflicts
      final conflicts = await checkConflicts(
        generatedSections: generatedSections,
        operatingLine: operatingLine,
        roadDirection: roadDirection,
        existingTrackSections: existingTrackSections,
      );

      // Create batch operation record
      String? batchId;
      if (_supabase.isInitialized) {
        batchId = await _supabase.createBatchOperation(
          startTrackSection: startTrackSection,
          endTrackSection: endTrackSection,
          startChainage: startChainage,
          endChainage: endChainage,
          lcsCode: lcsCode,
          operatingLine: operatingLine,
          roadDirection: roadDirection,
          station: station,
          vcc: vcc,
        );
      }

      // Handle conflicts based on resolution strategy
      final sectionsToInsert = <Map<String, dynamic>>[];

      if (conflictResolution == 'keep_existing') {
        // If any conflicts exist and resolution is 'keep_existing', stop here
        if (conflicts.isNotEmpty) {
          debugPrint('Batch operation stopped due to conflicts. User must resolve and retry.');

          if (batchId != null) {
            await _supabase.updateBatchOperationStatus(
              batchId,
              'failed',
              totalItems: generatedSections.length,
              conflictedItems: conflicts.length,
              conflictsData: {
                'conflicts': conflicts.map((k, v) => MapEntry(k.toString(), {
                      'proposed_chainage': v.proposedChainage,
                      'existing_chainage': v.existingChainage,
                      'difference': v.chainageDifference,
                    })),
              },
              errorLog: 'Operation stopped due to ${conflicts.length} conflicts. User chose to keep existing data.',
            );
          }

          return null;
        } else {
          sectionsToInsert.addAll(generatedSections);
        }
      } else if (conflictResolution == 'skip_conflicts') {
        // Skip conflicting sections
        for (final section in generatedSections) {
          final trackSectionNumber = section['track_section_number'] as int;
          if (!conflicts.containsKey(trackSectionNumber)) {
            sectionsToInsert.add(section);
          }
        }
      } else if (conflictResolution == 'replace_all') {
        // Replace all (delete existing and insert new)
        for (final section in generatedSections) {
          sectionsToInsert.add(section);
        }

        // TODO: Delete existing conflicting sections before inserting
      } else {
        // Default: insert all non-conflicting
        for (final section in generatedSections) {
          final trackSectionNumber = section['track_section_number'] as int;
          if (!conflicts.containsKey(trackSectionNumber)) {
            sectionsToInsert.add(section);
          }
        }
      }

      // Insert sections to local storage
      int successCount = 0;
      int failCount = 0;

      for (final sectionData in sectionsToInsert) {
        try {
          final trackSection = TrackSection(
            lcsCode: sectionData['lcs_code'] as String,
            legacyLcsCode: sectionData['legacy_lcs_code'] as String? ?? '',
            legacyJnpLcsCode: '',
            roadStatus: sectionData['road_status'] as String? ?? 'Active',
            operatingLineCode: sectionData['operating_line_code'] as String? ?? '',
            operatingLine: sectionData['operating_line'] as String,
            newLongDescription: '',
            newShortDescription: sectionData['station'] as String? ?? '',
            vcc: sectionData['vcc'] as String? ?? '',
            thalesChainage: (sectionData['thales_chainage'] as double).toString(),
            segmentId: '',
            lcsMeterageStart: sectionData['lcs_meterage'] as double,
            lcsMeterageEnd: sectionData['lcs_meterage_end'] as double? ?? 0,
            track: sectionData['track'] as String? ?? '',
            trackSection: (sectionData['track_section_number'] as int).toString(),
            physicalAssets: '',
            notes: 'Created via batch operation${batchId != null ? " ($batchId)" : ""}',
          );

          await _persistence.addUserTrackSection(trackSection);
          successCount++;
        } catch (e) {
          debugPrint('Error inserting track section: $e');
          failCount++;
        }
      }

      // Insert to Supabase if available and batch ID exists
      if (batchId != null && sectionsToInsert.isNotEmpty) {
        final supabaseSuccess = await _supabase.batchInsertTrackSections(
          batchId,
          sectionsToInsert,
        );

        if (supabaseSuccess) {
          await _supabase.updateBatchOperationStatus(
            batchId,
            'completed',
            totalItems: generatedSections.length,
            successfulItems: successCount,
            failedItems: failCount,
            conflictedItems: conflicts.length,
          );
        }
      }

      debugPrint('Batch operation completed: $successCount successful, $failCount failed, ${conflicts.length} conflicts');

      return batchId ?? 'local_only';
    } catch (e) {
      debugPrint('Error executing batch operation: $e');
      return null;
    }
  }

  /// Get operating line code from full name
  String _getLineCode(String operatingLine) {
    final lineLower = operatingLine.toLowerCase();
    if (lineLower.contains('district')) return 'D';
    if (lineLower.contains('circle')) return 'C';
    if (lineLower.contains('metropolitan')) return 'M';
    if (lineLower.contains('hammersmith')) return 'H';
    if (lineLower.contains('central')) return 'CEN';
    if (lineLower.contains('bakerloo')) return 'B';
    if (lineLower.contains('northern')) return 'N';
    if (lineLower.contains('piccadilly')) return 'P';
    if (lineLower.contains('victoria')) return 'V';
    if (lineLower.contains('jubilee')) return 'J';
    if (lineLower.contains('elizabeth')) return 'E';
    return '';
  }

  /// Validate batch operation parameters
  bool validateBatchParameters({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
  }) {
    // Check track section range
    if (startTrackSection == endTrackSection) {
      debugPrint('Error: Start and end track sections must be different');
      return false;
    }

    // Check chainage range
    if (startChainage == endChainage) {
      debugPrint('Error: Start and end chainage must be different');
      return false;
    }

    // Check that direction is consistent
    final tsIncreasing = endTrackSection > startTrackSection;
    final chainageIncreasing = endChainage > startChainage;

    if (tsIncreasing != chainageIncreasing) {
      debugPrint('Warning: Track section and chainage directions are inconsistent');
      // This is a warning, not an error - allow it but log it
    }

    return true;
  }

  /// Calculate preview statistics
  Map<String, dynamic> calculatePreviewStats({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
  }) {
    final totalSections = (endTrackSection - startTrackSection).abs() + 1;
    final totalChainageChange = (endChainage - startChainage).abs();
    final averageSpacing = totalSections > 1 ? totalChainageChange / (totalSections - 1) : 0;

    return {
      'totalSections': totalSections,
      'totalDistance': totalChainageChange,
      'averageSpacing': averageSpacing,
      'direction': endTrackSection > startTrackSection ? 'Increasing' : 'Decreasing',
    };
  }
}
