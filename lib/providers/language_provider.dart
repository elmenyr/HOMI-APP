import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  Locale _currentLocale;

  LanguageProvider() : _currentLocale = const Locale('en') {
    _loadSavedLanguage();
  }

  Locale get currentLocale => _currentLocale;
  bool get isArabic => _currentLocale.languageCode == 'ar';

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null) {
        _currentLocale = Locale(savedLanguage);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLocale.languageCode != languageCode) {
      try {
        _currentLocale = Locale(languageCode);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, languageCode);
        notifyListeners();
      } catch (e) {
        debugPrint('Error changing language: $e');
        // Revert to previous locale if there's an error
        _currentLocale = Locale(languageCode == 'ar' ? 'en' : 'ar');
        notifyListeners();
      }
    }
  }
} 