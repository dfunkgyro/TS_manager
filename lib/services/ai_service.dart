import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:track_sections_manager/services/unified_data_service.dart';

/// AI Service for enhanced search and data connections
class AIService {
  static AIService? _instance;
  String? _apiKey;
  bool _isConnected = false;
  String? _lastError;

  AIService._();

  factory AIService() {
    _instance ??= AIService._();
    return _instance!;
  }

  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  /// Initialize AI service with API key from .env
  Future<void> initialize() async {
    try {
      await dotenv.load(fileName: "assets/.env");
      _apiKey = dotenv.env['OPENAI_API_KEY'];
      
      if (_apiKey == null || _apiKey!.isEmpty) {
        _lastError = 'OPENAI_API_KEY not found in .env file';
        _isConnected = false;
        return;
      }
      
      // Test connection
      await _testConnection();
    } catch (e) {
      _lastError = 'Failed to load .env file: $e';
      _isConnected = false;
    }
  }

  Future<void> _testConnection() async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );
      
      _isConnected = response.statusCode == 200;
      if (!_isConnected) {
        _lastError = 'OpenAI API returned status ${response.statusCode}';
      }
    } catch (e) {
      _isConnected = false;
      _lastError = 'Connection test failed: $e';
    }
  }

  /// Enhanced search with AI assistance
  Future<String> enhancedSearch({
    required String query,
    String? lcsCode,
    String? line,
    List<String>? context,
  }) async {
    if (!_isConnected || _apiKey == null) {
      return 'AI service not connected. Please check your API key.';
    }

    try {
      final dataService = UnifiedDataService();
      final prompt = _buildSearchPrompt(query, lcsCode, line, context, dataService);
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert railway track sections assistant. Help users find track sections, LCS codes, and locations on the London Underground network.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.3,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        return 'AI search failed: ${response.statusCode}';
      }
    } catch (e) {
      return 'AI search error: $e';
    }
  }

  String _buildSearchPrompt(
    String query,
    String? lcsCode,
    String? line,
    List<String>? context,
    UnifiedDataService dataService,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('User Query: $query');
    
    if (lcsCode != null) {
      buffer.writeln('LCS Code: $lcsCode');
    }
    
    if (line != null) {
      buffer.writeln('Line: $line');
    }
    
    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context: ${context.join(", ")}');
    }
    
    // Add available data context
    if (dataService.isLoaded) {
      buffer.writeln('\nAvailable Data:');
      buffer.writeln('- ${dataService.allLcsCodes.length} LCS codes');
      buffer.writeln('- ${dataService.allLines.length} lines: ${dataService.allLines.join(", ")}');
      buffer.writeln('- ${dataService.allStations.length} stations');
    }
    
    buffer.writeln('\nPlease help the user find the relevant track sections, LCS codes, or locations. Provide specific, actionable information.');
    
    return buffer.toString();
  }

  /// Suggest missing data connections
  Future<Map<String, dynamic>> suggestConnections({
    required String lcsCode,
    required List<int> trackSectionIds,
  }) async {
    if (!_isConnected || _apiKey == null) {
      return {'error': 'AI service not connected'};
    }

    try {
      final prompt = '''
Analyze this LCS code and track section relationship:
- LCS Code: $lcsCode
- Track Section IDs: ${trackSectionIds.join(", ")}

Suggest:
1. Missing station/location information
2. Potential platform associations
3. Line information if missing
4. Any other relevant connections

Provide your response as JSON with keys: suggestions, confidence, reasoning.
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a railway data expert. Analyze LCS codes and track sections to suggest missing connections.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.2,
          'max_tokens': 800,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return jsonDecode(content) as Map<String, dynamic>;
      } else {
        return {'error': 'API returned ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Suggestion failed: $e'};
    }
  }

  /// Intelligent query processor with chainage calculation and context awareness
  Future<Map<String, dynamic>> processIntelligentQuery({
    required String query,
    required UnifiedDataService dataService,
  }) async {
    if (!_isConnected || _apiKey == null) {
      return {
        'error': 'AI service not connected',
        'fallback': _processFallbackQuery(query, dataService),
      };
    }

    try {
      // Build comprehensive context about available data
      final contextData = _buildDataContext(dataService);

      final prompt = '''
You are an expert AI assistant for a railway track sections management system. Process this user query intelligently:

USER QUERY: "$query"

SYSTEM CAPABILITIES & DATA:
$contextData

IMPORTANT RULES:
1. LCS Codes identify specific locations on the railway network
2. Chainage is an absolute position measurement along the railway
3. Meterage is a relative measurement from an LCS code's chainage start
4. Track Sections are identified by 5-digit numbers (e.g., 10501, 12345)
5. When a user adds meterage (e.g., "+50m"), add it to the base chainage
6. When a user subtracts meterage (e.g., "-50m"), subtract from the base chainage
7. If calculated chainage crosses into another station/LCS, identify and report it
8. Each location has: LCS code, station name, line/district, chainage, and track sections

TASK:
1. Parse the query to extract: LCS code, station, line, meterage adjustments, track sections
2. Calculate any chainage adjustments (additions/subtractions)
3. Identify if calculated position crosses into different station/LCS
4. Find all relevant track sections (5-digit numbers only)
5. Provide comprehensive results with all associated data

Respond with JSON containing:
{
  "understood_query": "natural language summary",
  "extracted_data": {
    "lcs_code": "string or null",
    "station": "string or null",
    "line": "string or null",
    "district": "string or null",
    "meterage_adjustment": number,
    "base_chainage": number,
    "calculated_chainage": number,
    "track_sections": [list of 5-digit numbers],
    "crosses_boundary": boolean,
    "new_station": "string or null if boundary crossed"
  },
  "search_strategy": "description of how to search",
  "results_summary": "what results to show user"
}
''';

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a railway track sections expert AI assistant. You understand LCS codes, chainage, meterage, track sections, stations, lines, and districts. Process queries intelligently and perform calculations accurately.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.1,
          'max_tokens': 2000,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        final aiResult = jsonDecode(content) as Map<String, dynamic>;

        // Enhance AI results with actual data lookups
        return _enhanceAIResults(aiResult, dataService);
      } else {
        return {
          'error': 'AI API returned ${response.statusCode}',
          'fallback': _processFallbackQuery(query, dataService),
        };
      }
    } catch (e) {
      return {
        'error': 'AI processing failed: $e',
        'fallback': _processFallbackQuery(query, dataService),
      };
    }
  }

  String _buildDataContext(UnifiedDataService dataService) {
    final buffer = StringBuffer();

    buffer.writeln('Available LCS Codes: ${dataService.allLcsCodes.take(20).join(", ")}... (${dataService.allLcsCodes.length} total)');
    buffer.writeln('Available Lines: ${dataService.allLines.join(", ")}');
    buffer.writeln('Available Stations: ${dataService.allStations.take(20).join(", ")}... (${dataService.allStations.length} total)');
    buffer.writeln('Total Track Sections: ${dataService.allTrackSections.length}');

    // Add examples
    buffer.writeln('\nEXAMPLE QUERIES:');
    buffer.writeln('- "Find LCS M187" → Look up LCS code M187, show station, line, track sections');
    buffer.writeln('- "Goldhawk Road +50m" → Find Goldhawk Road, add 50m to base chainage, show results');
    buffer.writeln('- "District line track section 10501" → Find track section 10501 on District line');
    buffer.writeln('- "BAK/A -25m" → Find LCS BAK/A, subtract 25m from chainage, check if crosses boundary');

    return buffer.toString();
  }

  Map<String, dynamic> _enhanceAIResults(
    Map<String, dynamic> aiResult,
    UnifiedDataService dataService,
  ) {
    final extractedData = aiResult['extracted_data'] as Map<String, dynamic>?;
    if (extractedData == null) return aiResult;

    final enhanced = Map<String, dynamic>.from(aiResult);
    final actualResults = <String, dynamic>{};

    // Look up actual LCS code if provided
    if (extractedData['lcs_code'] != null) {
      final lcsCode = extractedData['lcs_code'] as String;
      final lcs = dataService.findLcsByCode(lcsCode);
      if (lcs != null) {
        actualResults['lcs'] = {
          'code': lcs.displayCode,
          'description': lcs.shortDescription,
          'chainage_start': lcs.chainageStart,
          'chainage_end': lcs.chainageEnd,
          'vcc': lcs.vcc,
        };

        // Get station mapping
        final mapping = dataService.getStationMapping(lcs.displayCode);
        if (mapping != null) {
          actualResults['station'] = mapping.station;
          actualResults['line'] = mapping.line;
        }

        // Get track sections
        final trackSections = dataService.getTrackSectionsByLcs(lcs.displayCode);
        actualResults['track_sections'] = trackSections.map((ts) => {
          'id': ts.trackSection,
          'description': ts.newShortDescription,
          'line': ts.operatingLine,
          'lcs_current': ts.currentLcsCode,
          'lcs_legacy': ts.legacyLcsCode,
        }).toList();

        // Calculate chainage if meterage adjustment provided
        if (extractedData['meterage_adjustment'] != null) {
          final adjustment = (extractedData['meterage_adjustment'] as num).toDouble();
          final calculatedChainage = lcs.chainageStart + adjustment;
          actualResults['calculated_chainage'] = calculatedChainage;

          // Check if chainage crosses into different LCS
          final allLcs = dataService.allLcsRecords;
          for (final otherLcs in allLcs) {
            if (otherLcs.displayCode != lcs.displayCode &&
                calculatedChainage >= otherLcs.chainageStart &&
                calculatedChainage <= otherLcs.chainageEnd) {
              actualResults['crosses_boundary'] = true;
              actualResults['new_lcs'] = {
                'code': otherLcs.displayCode,
                'description': otherLcs.shortDescription,
              };
              final newMapping = dataService.getStationMapping(otherLcs.displayCode);
              if (newMapping != null) {
                actualResults['new_station'] = newMapping.station;
                actualResults['new_line'] = newMapping.line;
              }
              break;
            }
          }
        }
      }
    }

    // Look up by station name
    if (extractedData['station'] != null && actualResults['lcs'] == null) {
      final stationName = extractedData['station'] as String;
      final mappings = dataService.allStationMappings
          .where((m) => m.station.toLowerCase().contains(stationName.toLowerCase()))
          .toList();

      if (mappings.isNotEmpty) {
        actualResults['matching_stations'] = mappings.map((m) => {
          'station': m.station,
          'lcs_code': m.lcsCode,
          'line': m.line,
        }).toList();
      }
    }

    // Look up by line
    if (extractedData['line'] != null) {
      final line = extractedData['line'] as String;
      final lineSections = dataService.getTrackSectionsByLine(line);
      actualResults['line_track_sections_count'] = lineSections.length;
    }

    // Extract track sections from query (5-digit numbers)
    final trackSectionIds = extractedData['track_sections'] as List?;
    if (trackSectionIds != null && trackSectionIds.isNotEmpty) {
      actualResults['identified_track_sections'] = trackSectionIds;
    }

    enhanced['actual_data'] = actualResults;
    return enhanced;
  }

  Map<String, dynamic> _processFallbackQuery(
    String query,
    UnifiedDataService dataService,
  ) {
    // Basic fallback processing without AI
    final result = <String, dynamic>{
      'method': 'fallback',
      'query': query,
      'suggestions': <String>[],
    };

    // Extract potential LCS codes (patterns like M187, BAK/A, etc.)
    final lcsPattern = RegExp(r'\b[A-Z]{1,3}[/_-]?[A-Z0-9]{1,4}\b', caseSensitive: false);
    final lcsMatches = lcsPattern.allMatches(query);
    if (lcsMatches.isNotEmpty) {
      result['potential_lcs_codes'] = lcsMatches.map((m) => m.group(0)).toList();
      result['suggestions']!.add('Try searching for LCS code: ${lcsMatches.first.group(0)}');
    }

    // Extract 5-digit track sections
    final tsPattern = RegExp(r'\b\d{5}\b');
    final tsMatches = tsPattern.allMatches(query);
    if (tsMatches.isNotEmpty) {
      result['potential_track_sections'] = tsMatches.map((m) => m.group(0)).toList();
      result['suggestions']!.add('Found track section number: ${tsMatches.first.group(0)}');
    }

    // Extract meterage adjustments
    final meteragePattern = RegExp(r'[+-]\s*(\d+(?:\.\d+)?)\s*m', caseSensitive: false);
    final meterageMatches = meteragePattern.allMatches(query);
    if (meterageMatches.isNotEmpty) {
      result['meterage_adjustments'] = meterageMatches.map((m) => m.group(0)).toList();
      result['suggestions']!.add('Detected meterage adjustment: ${meterageMatches.first.group(0)}');
    }

    // Check for station names
    for (final station in dataService.allStations) {
      if (query.toLowerCase().contains(station.toLowerCase())) {
        result['potential_stations'] = [station];
        result['suggestions']!.add('Found station: $station');
        break;
      }
    }

    return result;
  }
}

