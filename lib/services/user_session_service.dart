import 'package:shared_preferences/shared_preferences.dart';

class UserSessionService {
  // Keys for SharedPreferences
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserType = 'user_type';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyRememberMe = 'remember_me';

  // Save user session data
  Future<void> saveUserSession({
    required String userId,
    required String email,
    required String userType,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserType, userType);
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setBool(_keyRememberMe, rememberMe);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Get user session data
  Future<Map<String, dynamic>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_keyUserId),
      'email': prefs.getString(_keyUserEmail),
      'userType': prefs.getString(_keyUserType),
      'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
      'rememberMe': prefs.getBool(_keyRememberMe) ?? false,
    };
  }

  // Clear user session data
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserType);
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyRememberMe);
  }
}
