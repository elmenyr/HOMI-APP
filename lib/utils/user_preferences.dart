import 'package:shared_preferences/shared_preferences.dart';

/// Class to manage user preferences and track login status
class UserPreferences {
  static const String _firstLoginKey = 'first_login';
  
  /// Check if this is the user's first login
  static Future<bool> isFirstLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_firstLoginKey}_$userId';
    return !(prefs.getBool(key) ?? false);
  }
  
  /// Mark that the user has logged in before
  static Future<void> markUserLoggedIn(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_firstLoginKey}_$userId';
    await prefs.setBool(key, true);
  }
  
  /// Reset user's first login status (for testing)
  static Future<void> resetFirstLoginStatus(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_firstLoginKey}_$userId';
    await prefs.remove(key);
  }
} 