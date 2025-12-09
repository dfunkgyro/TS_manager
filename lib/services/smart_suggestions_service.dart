// services/smart_suggestions_service.dart
import 'package:flutter/foundation.dart';
import '../models/track_data.dart';
import 'validation_rules_service.dart';

/// Smart suggestion for autocomplete
class SmartSuggestion {
  final String value;
  final String displayText;
  final String? subtitle;
  final double confidence; // 0.0 to 1.0
  final String source; // 'pattern', 'history', 'ai', 'database'

  SmartSuggestion({
    required this.value,
    required this.displayText,
    this.subtitle,
    this.confidence = 0.5,
    this.source = 'pattern',
  });

  @override
  String toString() {
    return 'SmartSuggestion{$displayText (${(confidence * 100).toStringAsFixed(0)}%)}';
  }
}

/// Service for providing smart data suggestions and autocomplete
class SmartSuggestionsService {
  static final SmartSuggestionsService _instance = SmartSuggestionsService._internal();
  factory SmartSuggestionsService() => _instance;
  SmartSuggestionsService._internal();

  final _validation = ValidationRulesService();

  /// Suggest next track section numbers based on existing pattern
  List<SmartSuggestion> suggestNextTrackSections(List<TrackSection> existingTrackSections) {
    if (existingTrackSections.isEmpty) {
      return [];
    }

    final suggestions = <SmartSuggestion>[];

    // Extract track section numbers
    final numbers = existingTrackSections
        .map((ts) => int.tryParse(ts.trackSection))
        .where((n) => n != null)
        .cast<int>()
        .toList();

    if (numbers.isEmpty) return [];

    // Get suggested next number
    final nextNumber = _validation.suggestNextTrackSectionNumber(numbers);

    if (nextNumber != null) {
      suggestions.add(SmartSuggestion(
        value: nextNumber.toString(),
        displayText: 'TS $nextNumber',
        subtitle: 'Next in sequence',
        confidence: 0.9,
        source: 'pattern',
      ));

      // Also suggest a few more
      for (int i = 1; i <= 3; i++) {
        final number = nextNumber + i;
        suggestions.add(SmartSuggestion(
          value: number.toString(),
          displayText: 'TS $number',
          subtitle: 'Continuing pattern',
          confidence: 0.8 - (i * 0.1),
          source: 'pattern',
        ));
      }
    }

    return suggestions;
  }

  /// Suggest LCS codes based on station and line
  List<SmartSuggestion> suggestLCSCodes({
    String? station,
    String? operatingLine,
    List<TrackSection>? existingTrackSections,
  }) {
    final suggestions = <SmartSuggestion>[];

    // If we have existing track sections on same line, suggest similar LCS codes
    if (operatingLine != null && existingTrackSections != null) {
      final sameLine = existingTrackSections
          .where((ts) => ts.operatingLine == operatingLine)
          .toList();

      if (sameLine.isNotEmpty) {
        // Find most common LCS codes
        final lcsCounts = <String, int>{};
        for (final ts in sameLine) {
          lcsCounts[ts.lcsCode] = (lcsCounts[ts.lcsCode] ?? 0) + 1;
        }

        // Sort by frequency
        final sortedLCS = lcsCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Add top suggestions
        for (final entry in sortedLCS.take(5)) {
          suggestions.add(SmartSuggestion(
            value: entry.key,
            displayText: entry.key,
            subtitle: 'Used ${entry.value} times on $operatingLine',
            confidence: 0.7,
            source: 'history',
          ));
        }
      }
    }

    // Line-specific pattern suggestions
    if (operatingLine != null) {
      final prefix = _getLinePrefix(operatingLine);
      if (prefix != null) {
        suggestions.addAll([
          SmartSuggestion(
            value: '${prefix}011',
            displayText: '${prefix}011',
            subtitle: 'Common start code for $operatingLine',
            confidence: 0.6,
            source: 'pattern',
          ),
          SmartSuggestion(
            value: '${prefix}001',
            displayText: '${prefix}001',
            subtitle: 'Terminal code for $operatingLine',
            confidence: 0.5,
            source: 'pattern',
          ),
        ]);
      }
    }

    return suggestions;
  }

  /// Suggest chainage based on adjacent sections
  List<SmartSuggestion> suggestChainage({
    required List<TrackSection> adjacentSections,
    bool isAfter = true,
  }) {
    if (adjacentSections.isEmpty) return [];

    final suggestions = <SmartSuggestion>[];

    // Sort by chainage
    final sorted = adjacentSections.toList()
      ..sort((a, b) {
        final aChain = double.tryParse(a.thalesChainage) ?? 0;
        final bChain = double.tryParse(b.thalesChainage) ?? 0;
        return aChain.compareTo(bChain);
      });

    // Calculate average spacing
    if (sorted.length >= 2) {
      double totalSpacing = 0;
      int count = 0;

      for (int i = 1; i < sorted.length; i++) {
        final prev = double.tryParse(sorted[i - 1].thalesChainage);
        final curr = double.tryParse(sorted[i].thalesChainage);

        if (prev != null && curr != null) {
          totalSpacing += (curr - prev).abs();
          count++;
        }
      }

      if (count > 0) {
        final avgSpacing = totalSpacing / count;
        final lastChainage = double.tryParse(sorted.last.thalesChainage);

        if (lastChainage != null) {
          final suggestedChainage = isAfter
              ? lastChainage + avgSpacing
              : lastChainage - avgSpacing;

          suggestions.add(SmartSuggestion(
            value: suggestedChainage.toStringAsFixed(1),
            displayText: '${suggestedChainage.toStringAsFixed(1)}m',
            subtitle: 'Based on ${avgSpacing.toStringAsFixed(1)}m average spacing',
            confidence: 0.85,
            source: 'pattern',
          ));

          // Also suggest slightly different spacings
          suggestions.add(SmartSuggestion(
            value: (suggestedChainage + 10).toStringAsFixed(1),
            displayText: '${(suggestedChainage + 10).toStringAsFixed(1)}m',
            subtitle: 'Slightly wider spacing',
            confidence: 0.6,
            source: 'pattern',
          ));

          suggestions.add(SmartSuggestion(
            value: (suggestedChainage - 10).toStringAsFixed(1),
            displayText: '${(suggestedChainage - 10).toStringAsFixed(1)}m',
            subtitle: 'Slightly narrower spacing',
            confidence: 0.6,
            source: 'pattern',
          ));
        }
      }
    }

    return suggestions;
  }

  /// Suggest road direction based on context
  List<SmartSuggestion> suggestRoadDirection({
    String? station,
    String? operatingLine,
    List<TrackSection>? existingTrackSections,
  }) {
    final suggestions = <SmartSuggestion>[];

    // If we have existing sections at this station, suggest same direction
    if (station != null && existingTrackSections != null) {
      final atStation = existingTrackSections
          .where((ts) => ts.newShortDescription == station)
          .toList();

      if (atStation.isNotEmpty) {
        final directions = atStation.map((ts) => ts.track).toSet();

        for (final dir in directions) {
          if (dir.isNotEmpty) {
            suggestions.add(SmartSuggestion(
              value: dir,
              displayText: dir,
              subtitle: 'Existing direction at $station',
              confidence: 0.8,
              source: 'history',
            ));
          }
        }
      }
    }

    // Add all standard directions
    final standardDirections = ['EB', 'WB', 'NB', 'SB'];
    for (final dir in standardDirections) {
      if (!suggestions.any((s) => s.value == dir)) {
        suggestions.add(SmartSuggestion(
          value: dir,
          displayText: dir,
          subtitle: _getDirectionFullName(dir),
          confidence: 0.5,
          source: 'pattern',
        ));
      }
    }

    return suggestions;
  }

  /// Detect anomalies in track section data
  List<String> detectAnomalies(TrackSection trackSection, List<TrackSection> allSections) {
    final anomalies = <String>[];

    final tsNumber = int.tryParse(trackSection.trackSection);
    final chainage = double.tryParse(trackSection.thalesChainage);

    if (tsNumber == null || chainage == null) return anomalies;

    // Find sections on same line and direction
    final sameLine = allSections.where((ts) {
      return ts.operatingLine == trackSection.operatingLine &&
          ts.track == trackSection.track &&
          ts.trackSection != trackSection.trackSection;
    }).toList();

    if (sameLine.isEmpty) return anomalies;

    // Check for unusual track section number gaps
    final numbers = sameLine
        .map((ts) => int.tryParse(ts.trackSection))
        .where((n) => n != null)
        .cast<int>()
        .toList()
      ..add(tsNumber)
      ..sort();

    final index = numbers.indexOf(tsNumber);
    if (index > 0 && index < numbers.length - 1) {
      final gapBefore = (tsNumber - numbers[index - 1]).abs();
      final gapAfter = (numbers[index + 1] - tsNumber).abs();

      if (gapBefore > 10 || gapAfter > 10) {
        anomalies.add(
          'Large gap in track section numbers (${gapBefore > 10 ? "-$gapBefore" : "+$gapAfter"}). Missing sections?',
        );
      }
    }

    // Check for unusual chainage
    final chainages = sameLine
        .map((ts) => double.tryParse(ts.thalesChainage))
        .where((c) => c != null)
        .cast<double>()
        .toList();

    if (chainages.isNotEmpty) {
      final avgChainage = chainages.reduce((a, b) => a + b) / chainages.length;
      final deviation = (chainage - avgChainage).abs();

      if (deviation > 5000) {
        anomalies.add(
          'Chainage ${chainage.toStringAsFixed(1)}m is unusually far from average (${avgChainage.toStringAsFixed(1)}m)',
        );
      }
    }

    // Check for LCS code pattern
    final lcsPattern = _getLinePrefix(trackSection.operatingLine);
    if (lcsPattern != null && !trackSection.lcsCode.startsWith(lcsPattern)) {
      anomalies.add(
        'LCS code "${trackSection.lcsCode}" doesn\'t match typical pattern for ${trackSection.operatingLine} ($lcsPattern###)',
      );
    }

    return anomalies;
  }

  /// Get line prefix for LCS codes
  String? _getLinePrefix(String operatingLine) {
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
    return null;
  }

  /// Get full direction name
  String _getDirectionFullName(String dir) {
    switch (dir) {
      case 'EB':
        return 'Eastbound';
      case 'WB':
        return 'Westbound';
      case 'NB':
        return 'Northbound';
      case 'SB':
        return 'Southbound';
      default:
        return dir;
    }
  }
}
