// services/validation_rules_service.dart
import 'package:flutter/foundation.dart';
import '../models/track_data.dart';

/// Validation result with error/warning messages
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> suggestions;

  ValidationResult({
    this.isValid = true,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;
  bool get hasIssues => hasErrors || hasWarnings;

  @override
  String toString() {
    return 'ValidationResult{valid: $isValid, errors: ${errors.length}, warnings: ${warnings.length}}';
  }
}

/// Service for validating track section data
class ValidationRulesService {
  static final ValidationRulesService _instance = ValidationRulesService._internal();
  factory ValidationRulesService() => _instance;
  ValidationRulesService._internal();

  // Line-specific LCS code patterns
  final Map<String, RegExp> _linePatterns = {
    'District Line': RegExp(r'^D\d{3}'),
    'Circle Line': RegExp(r'^C\d{3}'),
    'Metropolitan Line': RegExp(r'^M\d{3}'),
    'Hammersmith & City Line': RegExp(r'^H\d{3}'),
    'Central Line': RegExp(r'^CEN\d{3}'),
    'Bakerloo Line': RegExp(r'^B\d{3}'),
    'Northern Line': RegExp(r'^N\d{3}'),
    'Piccadilly Line': RegExp(r'^P\d{3}'),
    'Victoria Line': RegExp(r'^V\d{3}'),
    'Jubilee Line': RegExp(r'^J\d{3}'),
    'Elizabeth Line': RegExp(r'^E\d{3}'),
  };

  /// Validate track section number format (must be 5 digits)
  ValidationResult validateTrackSectionNumber(String trackSectionNumber) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule: Must be 5 digits
    if (!RegExp(r'^\d{5}$').hasMatch(trackSectionNumber)) {
      errors.add('Track section number must be exactly 5 digits');
    }

    // Warning: Unusual ranges
    final number = int.tryParse(trackSectionNumber);
    if (number != null) {
      if (number < 10000) {
        warnings.add('Track section number is unusually low (< 10000)');
      } else if (number > 99999) {
        warnings.add('Track section number exceeds expected range');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate LCS code format and line consistency
  ValidationResult validateLCSCode(String lcsCode, String? operatingLine) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    // Rule: LCS code format
    if (!RegExp(r'^[A-Z]{1,3}\d{3}').hasMatch(lcsCode)) {
      errors.add('LCS code must start with 1-3 letters followed by 3 digits (e.g., D011, CEN123)');
    }

    // Rule: Line-specific pattern matching
    if (operatingLine != null && _linePatterns.containsKey(operatingLine)) {
      final pattern = _linePatterns[operatingLine]!;
      if (!pattern.hasMatch(lcsCode)) {
        errors.add(
          'LCS code "$lcsCode" doesn\'t match the typical pattern for $operatingLine',
        );
        suggestions.add(
          'Typical pattern for $operatingLine: ${_getPatternExample(operatingLine)}',
        );
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Validate chainage value and sequence
  ValidationResult validateChainage({
    required double chainage,
    double? previousChainage,
    double? nextChainage,
    bool shouldIncrease = true,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule: Chainage must be positive
    if (chainage < 0) {
      errors.add('Chainage cannot be negative');
    }

    // Rule: Chainage must increase (or decrease) along the line
    if (previousChainage != null) {
      if (shouldIncrease && chainage <= previousChainage) {
        errors.add(
          'Chainage must increase along the line. Expected > ${previousChainage.toStringAsFixed(1)}m, got ${chainage.toStringAsFixed(1)}m',
        );
      } else if (!shouldIncrease && chainage >= previousChainage) {
        errors.add(
          'Chainage must decrease along the line. Expected < ${previousChainage.toStringAsFixed(1)}m, got ${chainage.toStringAsFixed(1)}m',
        );
      }

      // Warning: Large gaps
      final diff = (chainage - previousChainage).abs();
      if (diff > 500) {
        warnings.add(
          'Large gap in chainage (${diff.toStringAsFixed(1)}m). This may indicate missing track sections.',
        );
      } else if (diff < 10) {
        warnings.add(
          'Very small chainage difference (${diff.toStringAsFixed(1)}m). Adjacent sections are unusually close.',
        );
      }
    }

    if (nextChainage != null) {
      if (shouldIncrease && chainage >= nextChainage) {
        errors.add('Chainage must be less than next section (${nextChainage.toStringAsFixed(1)}m)');
      } else if (!shouldIncrease && chainage <= nextChainage) {
        errors.add('Chainage must be greater than next section (${nextChainage.toStringAsFixed(1)}m)');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate meterage is within LCS code range
  ValidationResult validateMeterageInRange({
    required double meterage,
    required String lcsCode,
    double? lcsStart,
    double? lcsEnd,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule: Meterage must be non-negative
    if (meterage < 0) {
      errors.add('Meterage cannot be negative');
    }

    // Rule: Meterage must be within LCS code range (if known)
    if (lcsStart != null && lcsEnd != null) {
      if (meterage < lcsStart || meterage > lcsEnd) {
        errors.add(
          'Meterage ${meterage.toStringAsFixed(1)}m is outside the range for $lcsCode (${lcsStart.toStringAsFixed(1)}m - ${lcsEnd.toStringAsFixed(1)}m)',
        );
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Check for duplicate track sections on same line/direction
  ValidationResult validateNoDuplicates({
    required int trackSectionNumber,
    required String operatingLine,
    required String roadDirection,
    required List<TrackSection> existingTrackSections,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Rule: No duplicate track section numbers on same line and direction
    final duplicates = existingTrackSections.where((ts) {
      final tsNumber = int.tryParse(ts.trackSection);
      return tsNumber == trackSectionNumber &&
          ts.operatingLine == operatingLine &&
          ts.track == roadDirection;
    }).toList();

    if (duplicates.isNotEmpty) {
      errors.add(
        'Track section $trackSectionNumber already exists on $operatingLine $roadDirection',
      );
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate complete track section entry
  ValidationResult validateTrackSection({
    required String trackSectionNumber,
    required String lcsCode,
    required double chainage,
    required double meterage,
    required String operatingLine,
    required String roadDirection,
    List<TrackSection>? existingTrackSections,
    double? previousChainage,
    double? nextChainage,
  }) {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    final allSuggestions = <String>[];

    // Validate track section number
    final tsResult = validateTrackSectionNumber(trackSectionNumber);
    allErrors.addAll(tsResult.errors);
    allWarnings.addAll(tsResult.warnings);

    // Validate LCS code
    final lcsResult = validateLCSCode(lcsCode, operatingLine);
    allErrors.addAll(lcsResult.errors);
    allWarnings.addAll(lcsResult.warnings);
    allSuggestions.addAll(lcsResult.suggestions);

    // Validate chainage
    final chainageResult = validateChainage(
      chainage: chainage,
      previousChainage: previousChainage,
      nextChainage: nextChainage,
    );
    allErrors.addAll(chainageResult.errors);
    allWarnings.addAll(chainageResult.warnings);

    // Validate no duplicates
    if (existingTrackSections != null) {
      final tsNumber = int.tryParse(trackSectionNumber);
      if (tsNumber != null) {
        final duplicateResult = validateNoDuplicates(
          trackSectionNumber: tsNumber,
          operatingLine: operatingLine,
          roadDirection: roadDirection,
          existingTrackSections: existingTrackSections,
        );
        allErrors.addAll(duplicateResult.errors);
        allWarnings.addAll(duplicateResult.warnings);
      }
    }

    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
      suggestions: allSuggestions,
    );
  }

  /// Auto-suggest next track section number based on pattern
  int? suggestNextTrackSectionNumber(List<int> existingNumbers) {
    if (existingNumbers.isEmpty) return null;
    if (existingNumbers.length < 2) return existingNumbers.first + 1;

    // Sort numbers
    final sorted = existingNumbers.toList()..sort();

    // Check if incrementing or decrementing
    final isIncreasing = sorted.last > sorted.first;

    // Calculate most common increment
    final increments = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      increments.add((sorted[i] - sorted[i - 1]).abs());
    }

    // Most common increment
    final incrementMap = <int, int>{};
    for (final inc in increments) {
      incrementMap[inc] = (incrementMap[inc] ?? 0) + 1;
    }

    int mostCommonIncrement = 1;
    int maxCount = 0;
    incrementMap.forEach((inc, count) {
      if (count > maxCount) {
        mostCommonIncrement = inc;
        maxCount = count;
      }
    });

    // Suggest next number
    if (isIncreasing) {
      return sorted.last + mostCommonIncrement;
    } else {
      return sorted.last - mostCommonIncrement;
    }
  }

  /// Auto-suggest LCS code based on station and line
  String? suggestLCSCode(String? station, String? operatingLine) {
    if (station == null || operatingLine == null) return null;

    // This would ideally query a database of known station-to-LCS mappings
    // For now, return null (placeholder for ML/database integration)
    return null;
  }

  /// Get pattern example for a line
  String _getPatternExample(String line) {
    switch (line) {
      case 'District Line':
        return 'D001, D011, D021, etc.';
      case 'Circle Line':
        return 'C001, C011, C021, etc.';
      case 'Metropolitan Line':
        return 'M001, M011, M021, etc.';
      case 'Central Line':
        return 'CEN001, CEN011, etc.';
      default:
        return 'Check line documentation';
    }
  }

  /// Validate batch operation parameters
  ValidationResult validateBatchParameters({
    required int startTrackSection,
    required int endTrackSection,
    required double startChainage,
    required double endChainage,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Must be different
    if (startTrackSection == endTrackSection) {
      errors.add('Start and end track sections must be different');
    }

    if (startChainage == endChainage) {
      errors.add('Start and end chainage must be different');
    }

    // Direction consistency
    final tsIncreasing = endTrackSection > startTrackSection;
    final chainageIncreasing = endChainage > startChainage;

    if (tsIncreasing != chainageIncreasing) {
      warnings.add(
        'Track section numbers and chainage are moving in opposite directions. This may indicate an error.',
      );
    }

    // Reasonable batch size
    final batchSize = (endTrackSection - startTrackSection).abs();
    if (batchSize > 100) {
      warnings.add(
        'Large batch size ($batchSize sections). Consider breaking into smaller batches for better performance.',
      );
    } else if (batchSize < 2) {
      warnings.add('Batch size is very small. Consider using manual entry instead.');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
