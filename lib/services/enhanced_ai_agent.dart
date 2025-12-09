import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:track_sections_manager/services/unified_data_service.dart';
import 'package:track_sections_manager/services/activity_logger.dart';

/// Enhanced AI Agent with fallback support and voice recognition
/// Supports OpenAI, DeepSeek, and local rule-based AI
class EnhancedAIAgent {
  static EnhancedAIAgent? _instance;
  String? _openAiKey;
  String? _deepseekKey;
  bool _isApiConnected = false;
  String? _lastError;
  AIProvider _currentProvider = AIProvider.none;
  final List<ChatMessage> _conversationHistory = [];

  // Fallback AI system
  final LocalAI _localAI = LocalAI();

  EnhancedAIAgent._();

  factory EnhancedAIAgent() {
    _instance ??= EnhancedAIAgent._();
    return _instance!;
  }

  bool get isApiConnected => _isApiConnected;
  String? get lastError => _lastError;
  AIProvider get currentProvider => _currentProvider;
  bool get hasAnyAI => _isApiConnected || true; // Always true because of local fallback
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  /// Initialize AI service with API keys from .env
  Future<void> initialize() async {
    final logger = ActivityLogger();

    try {
      logger.log('🤖 Initializing Enhanced AI Agent...', category: 'AI', level: LogLevel.info);

      // Try to load .env file
      try {
        await dotenv.load(fileName: "assets/.env");
        logger.log('✅ .env file loaded successfully', category: 'AI', level: LogLevel.success);
      } catch (e) {
        logger.log('⚠️  .env file not found, will use local AI only', category: 'AI', level: LogLevel.warning);
        _currentProvider = AIProvider.local;
        return;
      }

      _openAiKey = dotenv.env['OPENAI_API_KEY'];
      _deepseekKey = dotenv.env['DEEPSEEK_API_KEY'];

      logger.log('🔑 Checking API Keys...', category: 'AI', data: {
        'openai_present': _openAiKey != null && _openAiKey!.isNotEmpty,
        'openai_valid': _openAiKey != null && !_openAiKey!.contains('your_'),
        'deepseek_present': _deepseekKey != null && _deepseekKey!.isNotEmpty,
        'deepseek_valid': _deepseekKey != null && !_deepseekKey!.contains('your_'),
      });

      // Try OpenAI first
      if (_isValidKey(_openAiKey)) {
        _currentProvider = AIProvider.openai;
        logger.log('🔵 Attempting OpenAI connection...', category: 'AI');
        await _testConnection();
        if (_isApiConnected) {
          logger.log('✅ OpenAI connected successfully!', category: 'AI', level: LogLevel.success);
          return;
        }
      }

      // Try DeepSeek if OpenAI failed
      if (_isValidKey(_deepseekKey)) {
        _currentProvider = AIProvider.deepseek;
        logger.log('🟣 Attempting DeepSeek connection...', category: 'AI');
        await _testConnection();
        if (_isApiConnected) {
          logger.log('✅ DeepSeek connected successfully!', category: 'AI', level: LogLevel.success);
          return;
        }
      }

      // Fall back to local AI
      _lastError = 'No valid AI API keys found, using local AI fallback';
      _isApiConnected = false;
      _currentProvider = AIProvider.local;
      logger.log('🟡 Using local AI fallback', category: 'AI', level: LogLevel.warning);
    } catch (e) {
      _lastError = 'AI initialization error: $e';
      _isApiConnected = false;
      _currentProvider = AIProvider.local;
      logger.log('⚠️  Falling back to local AI: $e', category: 'AI', level: LogLevel.error);
    }
  }

  bool _isValidKey(String? key) {
    return key != null && key.isNotEmpty && !key.contains('your_');
  }

  Future<void> _testConnection() async {
    final logger = ActivityLogger();

    try {
      if (_currentProvider == AIProvider.openai) {
        final response = await http
            .get(
              Uri.parse('https://api.openai.com/v1/models'),
              headers: {'Authorization': 'Bearer $_openAiKey'},
            )
            .timeout(const Duration(seconds: 10));

        _isApiConnected = response.statusCode == 200;
        if (!_isApiConnected) {
          _lastError = 'OpenAI API returned status ${response.statusCode}: ${response.body}';
          logger.log(_lastError!, category: 'AI', level: LogLevel.error);
        }
      } else if (_currentProvider == AIProvider.deepseek) {
        // DeepSeek API endpoint - try the chat completions endpoint directly
        final response = await http
            .post(
              Uri.parse('https://api.deepseek.com/chat/completions'),
              headers: {
                'Authorization': 'Bearer $_deepseekKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'deepseek-chat',
                'messages': [
                  {'role': 'user', 'content': 'test'}
                ],
                'max_tokens': 1,
              }),
            )
            .timeout(const Duration(seconds: 10));

        // DeepSeek might return 400 for invalid request but that means API key is valid
        _isApiConnected = response.statusCode == 200 || response.statusCode == 400;
        if (!_isApiConnected) {
          _lastError = 'DeepSeek API returned status ${response.statusCode}: ${response.body}';
          logger.log(_lastError!, category: 'AI', level: LogLevel.error);
        }
      }
    } catch (e) {
      _isApiConnected = false;
      _lastError = 'Connection test failed: $e';
      logger.log(_lastError!, category: 'AI', level: LogLevel.error);
    }
  }

  /// Main chat method - handles all types of queries with fallback
  Future<String> chat(String userMessage, {Map<String, dynamic>? context}) async {
    final logger = ActivityLogger();

    // Add user message to history
    _conversationHistory.add(ChatMessage(
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
    ));

    logger.log('💬 User: $userMessage', category: 'AI');

    try {
      String response;

      // Try API first if connected
      if (_isApiConnected && _currentProvider != AIProvider.local) {
        response = await _chatWithAPI(userMessage, context);
      } else {
        // Use local AI fallback
        logger.log('🟡 Using local AI fallback', category: 'AI');
        response = await _localAI.processQuery(userMessage, context);
      }

      // Add assistant response to history
      _conversationHistory.add(ChatMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      ));

      logger.log('🤖 Assistant: ${response.substring(0, response.length > 100 ? 100 : response.length)}...', category: 'AI');

      return response;
    } catch (e) {
      logger.log('❌ Chat error: $e, falling back to local AI', category: 'AI', level: LogLevel.error);

      // Always fall back to local AI on error
      final fallbackResponse = await _localAI.processQuery(userMessage, context);
      _conversationHistory.add(ChatMessage(
        role: 'assistant',
        content: fallbackResponse,
        timestamp: DateTime.now(),
      ));

      return fallbackResponse;
    }
  }

  Future<String> _chatWithAPI(String userMessage, Map<String, dynamic>? context) async {
    final dataService = UnifiedDataService();
    final systemPrompt = _buildSystemPrompt(dataService);
    final userPrompt = _buildUserPrompt(userMessage, context, dataService);

    final endpoint = _currentProvider == AIProvider.openai
        ? 'https://api.openai.com/v1/chat/completions'
        : 'https://api.deepseek.com/chat/completions';

    final model = _currentProvider == AIProvider.openai ? 'gpt-4' : 'deepseek-chat';
    final apiKey = _currentProvider == AIProvider.openai ? _openAiKey : _deepseekKey;

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              ..._conversationHistory.take(10).map((msg) => {
                    'role': msg.role,
                    'content': msg.content,
                  }),
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.7,
            'max_tokens': 2000,
          }),
        )
        .timeout(const Duration(seconds': 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('API returned status ${response.statusCode}: ${response.body}');
    }
  }

  String _buildSystemPrompt(UnifiedDataService dataService) {
    return '''You are an intelligent AI assistant for the Railway Track Sections Manager app, designed to help users navigate and manage London Underground track sections, LCS codes, and station mappings.

Your capabilities:
1. **Track Section Management**: Help users find, create, update, and manage track sections
2. **LCS Code Lookup**: Search and explain LCS (Location Code System) codes and their relationships
3. **Station Mapping**: Connect stations with platforms, lines, and track sections
4. **TSR Management**: Assist with Temporary Speed Restrictions creation and monitoring
5. **Batch Operations**: Guide users through bulk data entry and updates
6. **Data Export**: Help export data in various formats (CSV, PDF, Excel)
7. **Navigation**: Direct users to the right screens and features
8. **Error Handling**: Understand incomplete sentences, typos, and contextual queries

Available Data Context:
- ${dataService.allLines.length} Underground lines: ${dataService.allLines.join(", ")}
- ${dataService.allStations.length} stations
- ${dataService.allLcsCodes.length} LCS codes
- ${dataService.allTrackSections.length} track sections

Communication Style:
- Be concise and actionable
- Use emojis sparingly for clarity (🚇 for trains, 📍 for locations, etc.)
- Understand context from previous messages
- Handle typos and incomplete sentences gracefully
- If user intent is unclear, ask clarifying questions

IMPORTANT: When users ask to perform actions (create, update, delete), provide step-by-step guidance on using the app's features rather than claiming you can do it directly.''';
  }

  String _buildUserPrompt(String userMessage, Map<String, dynamic>? context, UnifiedDataService dataService) {
    final buffer = StringBuffer();
    buffer.writeln('User Query: $userMessage');

    if (context != null && context.isNotEmpty) {
      buffer.writeln('\nContext:');
      context.forEach((key, value) {
        buffer.writeln('- $key: $value');
      });
    }

    return buffer.toString();
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Get AI status string
  String getStatusString() {
    if (_isApiConnected) {
      switch (_currentProvider) {
        case AIProvider.openai:
          return '🟢 Connected to OpenAI';
        case AIProvider.deepseek:
          return '🟢 Connected to DeepSeek AI';
        default:
          return '🟡 Local AI Active';
      }
    }
    return '🟡 Local AI Active (No API connection)';
  }
}

/// AI Provider enumeration
enum AIProvider {
  none,
  openai,
  deepseek,
  local,
}

/// Chat message model
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Local AI fallback system using pattern matching and rule-based responses
class LocalAI {
  final UnifiedDataService _dataService = UnifiedDataService();

  Future<String> processQuery(String query, Map<String, dynamic>? context) async {
    final queryLower = query.toLowerCase().trim();

    // Intent detection
    if (_isSearchQuery(queryLower)) {
      return _handleSearchQuery(queryLower, context);
    } else if (_isNavigationQuery(queryLower)) {
      return _handleNavigationQuery(queryLower);
    } else if (_isTSRQuery(queryLower)) {
      return _handleTSRQuery(queryLower);
    } else if (_isDataManagementQuery(queryLower)) {
      return _handleDataManagementQuery(queryLower);
    } else if (_isHelpQuery(queryLower)) {
      return _handleHelpQuery(queryLower);
    } else {
      return _handleGeneralQuery(queryLower, context);
    }
  }

  bool _isSearchQuery(String query) {
    final keywords = ['find', 'search', 'look', 'where', 'locate', 'show me', 'get', 'fetch'];
    return keywords.any((kw) => query.contains(kw));
  }

  bool _isNavigationQuery(String query) {
    final keywords = ['go to', 'open', 'navigate', 'take me', 'show', 'access', 'how to get'];
    return keywords.any((kw) => query.contains(kw));
  }

  bool _isTSRQuery(String query) {
    final keywords = ['tsr', 'speed restriction', 'temporary speed', 'restriction'];
    return keywords.any((kw) => query.contains(kw));
  }

  bool _isDataManagementQuery(String query) {
    final keywords = ['create', 'add', 'update', 'delete', 'remove', 'batch', 'bulk', 'export', 'import'];
    return keywords.any((kw) => query.contains(kw));
  }

  bool _isHelpQuery(String query) {
    final keywords = ['help', 'how', 'what', 'explain', 'tell me about', 'guide'];
    return keywords.any((kw) => query.contains(kw));
  }

  String _handleSearchQuery(String query, Map<String, dynamic>? context) {
    // Extract entities from query
    final lines = _extractLines(query);
    final stations = _extractStations(query);
    final lcsCode = _extractLCSCode(query);

    final buffer = StringBuffer();
    buffer.writeln('🔍 **Search Results:**\n');

    if (lcsCode != null) {
      buffer.writeln('📍 Found LCS Code: **$lcsCode**');
      buffer.writeln('Use the **LCS Code Search** screen to view details.\n');
    }

    if (lines.isNotEmpty) {
      buffer.writeln('🚇 Lines: ${lines.join(", ")}');
      buffer.writeln('Found ${lines.length} matching line(s).\n');
    }

    if (stations.isNotEmpty) {
      buffer.writeln('🏢 Stations: ${stations.take(5).join(", ")}');
      if (stations.length > 5) {
        buffer.writeln('...and ${stations.length - 5} more');
      }
    }

    if (buffer.length <= 50) {
      buffer.clear();
      buffer.writeln('🔍 To search for track sections:');
      buffer.writeln('1. Use **Unified Search** for comprehensive results');
      buffer.writeln('2. Try **LCS Code Search** for specific codes');
      buffer.writeln('3. Use **Meterage Search** for distance-based lookup\n');
      buffer.writeln('💡 Try being more specific: "Find track sections on District line" or "Search for LCS123"');
    }

    return buffer.toString();
  }

  String _handleNavigationQuery(String query) {
    final screens = {
      'unified search': '🔍 **Unified Search** - Tap the blue featured card on the home screen',
      'meterage': '📏 **Meterage Search** - Green card on home screen',
      'lcs': '🔷 **LCS Code Search** - Orange card on home screen',
      'tsr': '⚠️  **TSR Dashboard** - Red card on home screen for active speed restrictions',
      'batch': '⚡ **Batch Entry** - Blue card for quick data entry',
      'grouping': '🔗 **Grouping Manager** - Orange card for TSR groupings',
      'theme': '🎨 **Theme Settings** - Indigo card for dark mode and color themes',
      'export': '📥 **Data Export** - Brown card for exporting results',
      'training': '📚 **Track Section Training** - Purple card for data management',
    };

    for (final entry in screens.entries) {
      if (query.contains(entry.key)) {
        return '${entry.value}\n\nNavigate from the **Home Screen** to access this feature.';
      }
    }

    return '''🧭 **Available Screens:**

**Search & Lookup:**
🔍 Unified Search - All-in-one search with AI
📏 Meterage Search - Find by meterage value
🔷 LCS Code Search - Search by LCS code
🔍 Advanced Query - Combined search options

**Management:**
⚡ Batch Entry - Speed up data entry
🔗 Grouping Manager - Manage TSR groupings
⚠️  TSR Dashboard - Active speed restrictions
🎨 Theme Settings - Customize appearance

**Data:**
📥 Data Export - Export your data
📚 Track Section Training - Train & link data
🪛 Activity Logger - Debug & monitor

Where would you like to go?''';
  }

  String _handleTSRQuery(String query) {
    if (query.contains('create') || query.contains('add') || query.contains('new')) {
      return '''⚠️  **Creating a New TSR:**

1. Go to **Home** → **TSR Dashboard**
2. Tap the **"+" Create TSR** button
3. Follow the **5-step wizard**:
   - Step 1: Basic info (TSR number, name, reason)
   - Step 2: Location (LCS code, meterage, line)
   - Step 3: Speed limits and dates
   - Step 4: Select affected track sections
   - Step 5: Review and confirm

💡 You can also use **TSR Templates** for common scenarios!''';
    } else if (query.contains('view') || query.contains('show') || query.contains('list')) {
      return '''📊 **Viewing TSRs:**

Go to **Home** → **TSR Dashboard** to see:
- ⚡ Active TSRs with color-coded severity
- 📅 Planned TSRs and expiring restrictions
- 🔍 Filter by line, status, or speed limit
- ⏱️  Countdown timers for expiring TSRs

Tap any TSR card for details and quick actions (Extend, End Early, Modify).''';
    } else {
      return '''⚠️  **TSR (Temporary Speed Restriction) Management:**

**Features:**
- 🆕 Create TSRs with step-by-step wizard
- 📊 View active and planned restrictions
- 🔔 Get alerts for expiring TSRs
- 🎯 Auto-detect affected track sections
- 📋 Use templates for common scenarios

**Access:** Home → TSR Dashboard (Red card)

What would you like to do with TSRs?''';
    }
  }

  String _handleDataManagementQuery(String query) {
    if (query.contains('batch') || query.contains('bulk')) {
      return '''⚡ **Batch Operations:**

**Batch Entry:**
1. Go to **Home** → **Batch Entry**
2. Enter range details (start/end track sections, chainage)
3. Generate preview to check for conflicts
4. Execute batch operation

**Features:**
- Linear interpolation for meterage
- Automatic conflict detection
- Undo support
- Progress tracking

**Grouping Manager:**
- Create TSR groupings for common track sections
- Bulk assign track sections to groups
- Auto-generation based on patterns

💡 Save time by batching multiple entries!''';
    } else if (query.contains('export')) {
      return '''📥 **Data Export:**

1. Go to **Home** → **Data Export**
2. Choose format:
   - 📄 **CSV** - For Excel/Sheets
   - 📋 **PDF** - For reports
   - 📊 **JSON** - For backup/import

3. Select data to export
4. Save or share the file

**What you can export:**
- Track sections with full details
- LCS code mappings
- Station associations
- TSR records

Access: Home → Data Export (Brown card)''';
    } else {
      return '''🛠️ **Data Management:**

**Create/Add Data:**
- ⚡ Batch Entry - Multiple track sections at once
- 📚 Track Section Training - Link and train data
- ⚠️  TSR Creation - New speed restrictions

**Update/Modify:**
- 🔍 Search and edit individual records
- 🔗 Manage groupings and associations
- ⚙️  Bulk operations with conflict resolution

**Export/Import:**
- 📥 Export data (CSV, PDF, JSON)
- 📤 Share with team members

What would you like to manage?''';
    }
  }

  String _handleHelpQuery(String query) {
    if (query.contains('lcs') && query.contains('code')) {
      return '''📍 **LCS (Location Code System) Explained:**

LCS codes are unique identifiers for specific locations on the railway network.

**Format:** Usually like "LCS123" or "ABC-001"

**Usage:**
- Identify exact positions on track
- Link stations to track sections
- Map meterage points
- Reference in TSRs

**Search for LCS Codes:**
- Home → LCS Code Search
- Home → Unified Search (supports LCS lookup)

**Finding Related Data:**
- Enter LCS code to see associated track sections
- View meterage ranges
- See connected platforms/stations''';
    } else if (query.contains('track section')) {
      return '''🛤️ **Track Sections Explained:**

Track sections are segments of railway track identified by numbers.

**Properties:**
- Track Section Number (5 digits)
- Associated LCS Code
- Operating Line (e.g., District, Circle)
- Road Direction (EB/WB/NB/SB)
- Chainage values
- Meterage from LCS
- Physical assets/notes

**Management:**
- Create: Batch Entry or Training screen
- Search: Multiple search options available
- Update: Find and edit
- Group: For TSR management

**Validation:**
- Must be 5 digits
- Chainage must increase along line
- No duplicates on same line/direction''';
    } else {
      return '''❓ **Help & Features:**

**🏠 Main Features:**
1. **Unified Search** - AI-powered search for everything
2. **TSR Management** - Speed restrictions tracking
3. **Batch Operations** - Quick data entry
4. **Data Export** - Share your data
5. **Theme Customization** - Dark mode & colors

**📱 Getting Started:**
- Explore the home screen cards
- Each card leads to a major feature
- Use Unified Search for quick lookups
- Check Activity Logger for debugging

**💬 Ask Me:**
- "How do I create a TSR?"
- "Show me District line track sections"
- "Export data to CSV"
- "Go to batch entry"

What would you like help with?''';
    }
  }

  String _handleGeneralQuery(String query, Map<String, dynamic>? context) {
    // Try to extract useful info from context
    if (context != null) {
      final contextInfo = StringBuffer();
      if (context.containsKey('screen')) {
        contextInfo.write('Currently on: ${context['screen']}\n');
      }
      if (context.containsKey('selected_line')) {
        contextInfo.write('Selected line: ${context['selected_line']}\n');
      }
    }

    // Default helpful response
    return '''👋 Hello! I'm your Railway Track Sections Manager AI assistant.

**I can help you with:**
- 🔍 Finding track sections, LCS codes, and stations
- 🧭 Navigating to different app features
- ⚠️  Managing Temporary Speed Restrictions (TSRs)
- ⚡ Batch data entry and operations
- 📥 Exporting data
- ❓ Explaining app features

**Try asking:**
- "Find track sections on the Central line"
- "How do I create a TSR?"
- "Go to batch entry"
- "Export my data to CSV"
- "What is an LCS code?"

💡 I understand context, so you can be conversational!

What can I help you with today?''';
  }

  List<String> _extractLines(String query) {
    final allLines = _dataService.allLines;
    return allLines.where((line) => query.contains(line.toLowerCase())).toList();
  }

  List<String> _extractStations(String query) {
    final allStations = _dataService.allStations;
    return allStations.where((station) => query.contains(station.toLowerCase())).take(10).toList();
  }

  String? _extractLCSCode(String query) {
    // Pattern to match LCS codes (e.g., LCS123, ABC-001)
    final lcsPattern = RegExp(r'\b[A-Z]{2,4}[-]?\d{2,4}\b', caseSensitive: false);
    final match = lcsPattern.firstMatch(query);
    return match?.group(0)?.toUpperCase();
  }
}
