// services/app_config.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Application configuration service
/// Loads configuration from .env file or uses defaults
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  String? _supabaseUrl;
  String? _supabaseAnonKey;
  String? _openaiApiKey;
  String? _deepseekApiKey;

  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasSupabaseConfig => _supabaseUrl != null && _supabaseAnonKey != null;
  bool get hasOpenAIConfig => _openaiApiKey != null;
  bool get hasDeepSeekConfig => _deepseekApiKey != null;

  String? get supabaseUrl => _supabaseUrl;
  String? get supabaseAnonKey => _supabaseAnonKey;
  String? get openaiApiKey => _openaiApiKey;
  String? get deepseekApiKey => _deepseekApiKey;

  /// Initialize configuration from .env file
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Try to load .env file from assets
      final envContent = await rootBundle.loadString('assets/.env');
      _parseEnvContent(envContent);
      debugPrint('Configuration loaded from assets/.env');
    } catch (e) {
      debugPrint('No .env file found, using defaults or environment variables: $e');
      _loadDefaults();
    }

    _initialized = true;
  }

  /// Parse .env file content
  void _parseEnvContent(String content) {
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Skip empty lines and comments
      if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
        continue;
      }

      // Parse key=value pairs
      final parts = trimmedLine.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();

        // Remove quotes if present
        final cleanValue = value.replaceAll(RegExp(r'^["\']|["\']$'), '');

        _setConfigValue(key, cleanValue);
      }
    }
  }

  /// Set configuration value by key
  void _setConfigValue(String key, String value) {
    // Skip placeholder values
    if (value.startsWith('your_') || value.contains('_here')) {
      return;
    }

    switch (key) {
      case 'SUPABASE_URL':
        _supabaseUrl = value;
        break;
      case 'SUPABASE_ANON_KEY':
        _supabaseAnonKey = value;
        break;
      case 'OPENAI_API_KEY':
        _openaiApiKey = value;
        break;
      case 'DEEPSEEK_API_KEY':
        _deepseekApiKey = value;
        break;
    }
  }

  /// Load default configuration (for development)
  void _loadDefaults() {
    // You can set defaults here for development
    // or leave them null to work offline
    debugPrint('Using default configuration (offline mode)');
  }

  /// Manually set Supabase configuration
  void setSupabaseConfig({
    required String url,
    required String anonKey,
  }) {
    _supabaseUrl = url;
    _supabaseAnonKey = anonKey;
  }

  /// Manually set OpenAI configuration
  void setOpenAIConfig(String apiKey) {
    _openaiApiKey = apiKey;
  }

  /// Manually set DeepSeek configuration
  void setDeepSeekConfig(String apiKey) {
    _deepseekApiKey = apiKey;
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> getSummary() {
    return {
      'initialized': _initialized,
      'hasSupabaseConfig': hasSupabaseConfig,
      'hasOpenAIConfig': hasOpenAIConfig,
      'hasDeepSeekConfig': hasDeepSeekConfig,
      'supabaseUrl': _supabaseUrl != null ? '${_supabaseUrl!.substring(0, 20)}...' : 'Not set',
    };
  }

  /// Validate configuration
  bool validate() {
    if (!_initialized) {
      debugPrint('AppConfig not initialized');
      return false;
    }

    bool isValid = true;

    if (!hasSupabaseConfig) {
      debugPrint('Warning: Supabase configuration not set - app will run in offline mode');
      isValid = false;
    }

    if (!hasOpenAIConfig && !hasDeepSeekConfig) {
      debugPrint('Warning: No AI API keys configured - AI features will be disabled');
    }

    return isValid;
  }
}
