import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys
const _kThemeMode = 'themeMode';
const _kPrimaryColor = 'primaryColor';
const _kSecondaryColor = 'secondaryColor';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.blueAccent;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;

  ThemeProvider() {
    _loadTheme();
  }

  // ── Persistence ──────────────────────────────────────────────

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    _themeMode = _parseThemeMode(prefs.getString(_kThemeMode) ?? 'system');

    final primary = prefs.getInt(_kPrimaryColor);
    final secondary = prefs.getInt(_kSecondaryColor);
    if (primary != null) _primaryColor = Color(primary);
    if (secondary != null) _secondaryColor = Color(secondary);

    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _themeMode.name);
    await prefs.setInt(_kPrimaryColor, _primaryColor.toARGB32());
    await prefs.setInt(_kSecondaryColor, _secondaryColor.toARGB32());
  }

  // ── Public API ───────────────────────────────────────────────

  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
      case ThemeMode.dark:
        _themeMode = ThemeMode.system;
      case ThemeMode.system:
        _themeMode = ThemeMode.light;
    }
    notifyListeners();
    await _saveTheme();
  }

  /// Set theme mode directly (used by PersonalisationPage picker).
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveTheme();
  }

  /// Kept for backward compatibility.
  Future<void> setTheme(ThemeMode mode) => setThemeMode(mode);

  /// Set accent colours and persist immediately.
  Future<void> setAccentColor(Color primary, Color secondary) async {
    _primaryColor = primary;
    _secondaryColor = secondary;
    notifyListeners();
    await _saveTheme();
  }

  // ── Helpers ──────────────────────────────────────────────────

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
