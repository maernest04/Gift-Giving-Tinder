import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { vibrantDark, glass }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  AppTheme _currentTheme = AppTheme.vibrantDark;
  bool _hapticFeedback = true;
  bool _showSwiped = true;

  AppTheme get currentTheme => _currentTheme;
  bool get hapticFeedback => _hapticFeedback;
  bool get showSwipedItems => _showSwiped;
  bool get isGlass => _currentTheme == AppTheme.glass;

  // Initialize preferences from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    final themeIndex = prefs.getInt('appTheme') ?? 0;
    _currentTheme = AppTheme.values[themeIndex];

    // Load Experience settings
    _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
    _showSwiped = prefs.getBool('showSwipedItems') ?? true;

    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('appTheme', theme.index);
      notifyListeners();
    }
  }

  Future<void> setHapticFeedback(bool enabled) async {
    if (_hapticFeedback != enabled) {
      _hapticFeedback = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hapticFeedback', enabled);
      notifyListeners();
    }
  }

  Future<void> setShowSwipedItems(bool enabled) async {
    if (_showSwiped != enabled) {
      _showSwiped = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showSwipedItems', enabled);
      notifyListeners();
    }
  }
}

final themeService = ThemeService();
