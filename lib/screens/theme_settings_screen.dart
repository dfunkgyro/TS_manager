// screens/theme_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// Screen for theme and appearance settings
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Appearance'),
      ),
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: 'Theme Mode',
                icon: Icons.palette,
                children: [
                  _buildThemeModeOption(
                    context,
                    themeService,
                    AppThemeMode.light,
                    'Light Mode',
                    Icons.light_mode,
                  ),
                  _buildThemeModeOption(
                    context,
                    themeService,
                    AppThemeMode.dark,
                    'Dark Mode',
                    Icons.dark_mode,
                  ),
                  _buildThemeModeOption(
                    context,
                    themeService,
                    AppThemeMode.oled,
                    'OLED Mode (Pure Black)',
                    Icons.brightness_1,
                  ),
                  _buildThemeModeOption(
                    context,
                    themeService,
                    AppThemeMode.system,
                    'System Default',
                    Icons.settings_suggest,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Auto-Switch',
                icon: Icons.schedule,
                children: [
                  SwitchListTile(
                    title: const Text('Auto-switch to dark mode'),
                    subtitle: const Text('Automatically switch based on time'),
                    value: themeService.autoSwitchEnabled,
                    onChanged: (value) {
                      themeService.setAutoSwitch(value);
                    },
                  ),
                  if (themeService.autoSwitchEnabled) ...[
                    ListTile(
                      title: const Text('Dark mode starts at'),
                      subtitle: Text(themeService.darkModeStartTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectTime(
                        context,
                        themeService,
                        isStart: true,
                      ),
                    ),
                    ListTile(
                      title: const Text('Dark mode ends at'),
                      subtitle: Text(themeService.darkModeEndTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectTime(
                        context,
                        themeService,
                        isStart: false,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Line Theme',
                icon: Icons.train,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Choose a color theme based on your favorite London Underground line',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LineTheme.values.map((theme) {
                      return _buildLineThemeChip(context, themeService, theme);
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Custom Accent Color',
                icon: Icons.color_lens,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Choose a custom accent color (overrides line theme)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._buildColorOptions(themeService),
                      if (themeService.customAccentColor != null)
                        ActionChip(
                          label: const Text('Reset'),
                          onPressed: () {
                            themeService.setCustomAccentColor(null);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context,
    ThemeService themeService,
    AppThemeMode mode,
    String label,
    IconData icon,
  ) {
    return RadioListTile<AppThemeMode>(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
      value: mode,
      groupValue: themeService.themeMode,
      onChanged: (value) {
        if (value != null) {
          themeService.setThemeMode(value);
        }
      },
    );
  }

  Widget _buildLineThemeChip(
    BuildContext context,
    ThemeService themeService,
    LineTheme theme,
  ) {
    final isSelected = themeService.lineTheme == theme;
    final color = _getThemeColor(theme);

    return FilterChip(
      label: Text(_getThemeName(theme)),
      selected: isSelected,
      onSelected: (_) {
        themeService.setLineTheme(theme);
      },
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  List<Widget> _buildColorOptions(ThemeService themeService) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.orange,
      Colors.deepOrange,
    ];

    return colors.map((color) {
      final isSelected = themeService.customAccentColor?.value == color.value;
      return GestureDetector(
        onTap: () {
          themeService.setCustomAccentColor(color);
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
          child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
        ),
      );
    }).toList();
  }

  Future<void> _selectTime(
    BuildContext context,
    ThemeService themeService, {
    required bool isStart,
  }) async {
    final initialTime = isStart ? themeService.darkModeStartTime : themeService.darkModeEndTime;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      themeService.setDarkModeTime(
        start: isStart ? time : null,
        end: !isStart ? time : null,
      );
    }
  }

  Color _getThemeColor(LineTheme theme) {
    switch (theme) {
      case LineTheme.district:
        return const Color(0xFF00843D);
      case LineTheme.circle:
        return const Color(0xFFFFD329);
      case LineTheme.metropolitan:
        return const Color(0xFF9B0058);
      case LineTheme.hammersmith:
        return const Color(0xFFF491A8);
      case LineTheme.central:
        return const Color(0xFFDC241F);
      case LineTheme.bakerloo:
        return const Color(0xFFB36305);
      case LineTheme.northern:
        return Colors.black;
      case LineTheme.piccadilly:
        return const Color(0xFF003688);
      case LineTheme.victoria:
        return const Color(0xFF0098D8);
      case LineTheme.jubilee:
        return const Color(0xFFA1A5A7);
      case LineTheme.elizabeth:
        return const Color(0xFF6950A1);
      case LineTheme.default_:
      default:
        return Colors.blue;
    }
  }

  String _getThemeName(LineTheme theme) {
    switch (theme) {
      case LineTheme.district:
        return 'District';
      case LineTheme.circle:
        return 'Circle';
      case LineTheme.metropolitan:
        return 'Metropolitan';
      case LineTheme.hammersmith:
        return 'Hammersmith & City';
      case LineTheme.central:
        return 'Central';
      case LineTheme.bakerloo:
        return 'Bakerloo';
      case LineTheme.northern:
        return 'Northern';
      case LineTheme.piccadilly:
        return 'Piccadilly';
      case LineTheme.victoria:
        return 'Victoria';
      case LineTheme.jubilee:
        return 'Jubilee';
      case LineTheme.elizabeth:
        return 'Elizabeth';
      case LineTheme.default_:
      default:
        return 'Default';
    }
  }
}
