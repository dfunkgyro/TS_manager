// services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences.dart';

/// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system,
  oled, // Pure black for OLED screens
}

/// Line-specific color themes
enum LineTheme {
  district, // Green
  circle, // Yellow
  metropolitan, // Purple
  hammersmith, // Pink
  central, // Red
  bakerloo, // Brown
  northern, // Black
  piccadilly, // Dark Blue
  victoria, // Light Blue
  jubilee, // Silver
  elizabeth, // Purple
  default_, // Blue
}

/// Service for managing app theme and appearance
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    _loadThemePreferences();
  }

  AppThemeMode _themeMode = AppThemeMode.system;
  LineTheme _lineTheme = LineTheme.default_;
  bool _autoSwitchEnabled = false;
  TimeOfDay _darkModeStartTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _darkModeEndTime = const TimeOfDay(hour: 6, minute: 0);
  Color? _customAccentColor;

  AppThemeMode get themeMode => _themeMode;
  LineTheme get lineTheme => _lineTheme;
  bool get autoSwitchEnabled => _autoSwitchEnabled;
  TimeOfDay get darkModeStartTime => _darkModeStartTime;
  TimeOfDay get darkModeEndTime => _darkModeEndTime;
  Color? get customAccentColor => _customAccentColor;

  /// Get effective theme mode
  ThemeMode get effectiveThemeMode {
    if (_themeMode == AppThemeMode.system) {
      return ThemeMode.system;
    } else if (_themeMode == AppThemeMode.light) {
      return ThemeMode.light;
    } else {
      // Dark or OLED
      if (_autoSwitchEnabled && !_isInDarkModeTime()) {
        return ThemeMode.light;
      }
      return ThemeMode.dark;
    }
  }

  /// Check if current time is within dark mode period
  bool _isInDarkModeTime() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _darkModeStartTime.hour * 60 + _darkModeStartTime.minute;
    final endMinutes = _darkModeEndTime.hour * 60 + _darkModeEndTime.minute;

    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Wraps around midnight
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _saveThemePreferences();
    notifyListeners();
  }

  /// Set line theme
  Future<void> setLineTheme(LineTheme theme) async {
    _lineTheme = theme;
    await _saveThemePreferences();
    notifyListeners();
  }

  /// Set custom accent color
  Future<void> setCustomAccentColor(Color? color) async {
    _customAccentColor = color;
    await _saveThemePreferences();
    notifyListeners();
  }

  /// Enable/disable auto-switch
  Future<void> setAutoSwitch(bool enabled) async {
    _autoSwitchEnabled = enabled;
    await _saveThemePreferences();
    notifyListeners();
  }

  /// Set dark mode time range
  Future<void> setDarkModeTime({
    TimeOfDay? start,
    TimeOfDay? end,
  }) async {
    if (start != null) _darkModeStartTime = start;
    if (end != null) _darkModeEndTime = end;
    await _saveThemePreferences();
    notifyListeners();
  }

  /// Get light theme
  ThemeData get lightTheme {
    final primaryColor = _getLineColor();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _customAccentColor ?? primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(color: primaryColor),
      ),
    );
  }

  /// Get dark theme
  ThemeData get darkTheme {
    final isOLED = _themeMode == AppThemeMode.oled;
    final backgroundColor = isOLED ? Colors.black : const Color(0xFF121212);
    final surfaceColor = isOLED ? const Color(0xFF0A0A0A) : const Color(0xFF1E1E1E);
    final primaryColor = _getLineColor();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _customAccentColor ?? primaryColor,
        brightness: Brightness.dark,
        background: backgroundColor,
        surface: surfaceColor,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: isOLED ? Colors.black : const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardTheme(
        elevation: 4,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.2),
        labelStyle: TextStyle(color: primaryColor.shade200),
      ),
    );
  }

  /// Get line-specific color
  Color _getLineColor() {
    switch (_lineTheme) {
      case LineTheme.district:
        return const Color(0xFF00843D); // Green
      case LineTheme.circle:
        return const Color(0xFFFFD329); // Yellow
      case LineTheme.metropolitan:
        return const Color(0xFF9B0058); // Purple
      case LineTheme.hammersmith:
        return const Color(0xFFF491A8); // Pink
      case LineTheme.central:
        return const Color(0xFFDC241F); // Red
      case LineTheme.bakerloo:
        return const Color(0xFFB36305); // Brown
      case LineTheme.northern:
        return Colors.black;
      case LineTheme.piccadilly:
        return const Color(0xFF003688); // Dark Blue
      case LineTheme.victoria:
        return const Color(0xFF0098D8); // Light Blue
      case LineTheme.jubilee:
        return const Color(0xFFA1A5A7); // Silver
      case LineTheme.elizabeth:
        return const Color(0xFF6950A1); // Purple
      case LineTheme.default_:
      default:
        return Colors.blue;
    }
  }

  /// Load theme preferences from storage
  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final themeModeIndex = prefs.getInt('theme_mode') ?? AppThemeMode.system.index;
      _themeMode = AppThemeMode.values[themeModeIndex];

      final lineThemeIndex = prefs.getInt('line_theme') ?? LineTheme.default_.index;
      _lineTheme = LineTheme.values[lineThemeIndex];

      _autoSwitchEnabled = prefs.getBool('auto_switch') ?? false;

      final startHour = prefs.getInt('dark_start_hour') ?? 20;
      final startMinute = prefs.getInt('dark_start_minute') ?? 0;
      _darkModeStartTime = TimeOfDay(hour: startHour, minute: startMinute);

      final endHour = prefs.getInt('dark_end_hour') ?? 6;
      final endMinute = prefs.getInt('dark_end_minute') ?? 0;
      _darkModeEndTime = TimeOfDay(hour: endHour, minute: endMinute);

      final accentColorValue = prefs.getInt('custom_accent_color');
      if (accentColorValue != null) {
        _customAccentColor = Color(accentColorValue);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  /// Save theme preferences to storage
  Future<void> _saveThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('theme_mode', _themeMode.index);
      await prefs.setInt('line_theme', _lineTheme.index);
      await prefs.setBool('auto_switch', _autoSwitchEnabled);
      await prefs.setInt('dark_start_hour', _darkModeStartTime.hour);
      await prefs.setInt('dark_start_minute', _darkModeStartTime.minute);
      await prefs.setInt('dark_end_hour', _darkModeEndTime.hour);
      await prefs.setInt('dark_end_minute', _darkModeEndTime.minute);

      if (_customAccentColor != null) {
        await prefs.setInt('custom_accent_color', _customAccentColor!.value);
      } else {
        await prefs.remove('custom_accent_color');
      }
    } catch (e) {
      debugPrint('Error saving theme preferences: $e');
    }
  }

  /// Get line theme from line name
  static LineTheme getLineThemeFromName(String lineName) {
    final lower = lineName.toLowerCase();
    if (lower.contains('district')) return LineTheme.district;
    if (lower.contains('circle')) return LineTheme.circle;
    if (lower.contains('metropolitan')) return LineTheme.metropolitan;
    if (lower.contains('hammersmith')) return LineTheme.hammersmith;
    if (lower.contains('central')) return LineTheme.central;
    if (lower.contains('bakerloo')) return LineTheme.bakerloo;
    if (lower.contains('northern')) return LineTheme.northern;
    if (lower.contains('piccadilly')) return LineTheme.piccadilly;
    if (lower.contains('victoria')) return LineTheme.victoria;
    if (lower.contains('jubilee')) return LineTheme.jubilee;
    if (lower.contains('elizabeth')) return LineTheme.elizabeth;
    return LineTheme.default_;
  }
}
