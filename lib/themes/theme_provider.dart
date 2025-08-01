import 'package:echospace/themes/dark_mode.dart';
import 'package:echospace/themes/light_mode.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = lightMode;
  Color _accentColor = Colors.blue; // Default accent color

  ThemeProvider() {
    _loadPreferences(); // Load theme and accent color on startup
  }

  ThemeData get themeData => _themeData;
  Color get accentColor => _accentColor;
  bool get isDarkMode => _themeData == darkMode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    _saveThemeMode();
    notifyListeners();
  }

  set accentColor(Color color) {
    _accentColor = color;
    _saveAccentColor();
    notifyListeners();
  }

  void toggleTheme() {
    _themeData = isDarkMode ? lightMode : darkMode;
    _saveThemeMode();
    notifyListeners();
  }

  /// Save Theme Mode
  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }

  /// Save Accent Color
  Future<void> _saveAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('accentColor', _accentColor.value);
  }

  /// Load Preferences on Startup
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    bool savedDarkMode = prefs.getBool('isDarkMode') ?? false;
    int savedAccentColor = prefs.getInt('accentColor') ?? Colors.blue.value;

    _themeData = savedDarkMode ? darkMode : lightMode;
    _accentColor = Color(savedAccentColor);

    notifyListeners(); // Ensure UI updates with the correct values
  }
}
