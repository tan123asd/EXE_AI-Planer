import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() {
    _isDarkMode = _storage.isDarkMode();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.saveThemeMode(_isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF4A90E2),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    useMaterial3: true,
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF4A90E2),
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    cardColor: const Color(0xFF16213E),
    useMaterial3: true,
  );
}
