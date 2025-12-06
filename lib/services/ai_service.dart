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
}

