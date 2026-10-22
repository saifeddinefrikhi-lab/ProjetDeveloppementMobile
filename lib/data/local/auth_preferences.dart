import 'package:shared_preferences/shared_preferences.dart';

/// Manages the logged-in user session via SharedPreferences.
class AuthPreferences {
  static const _keyUserId = 'auth_user_id';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserInitials = 'auth_user_initials';

  Future<void> saveSession({
    required int userId,
    required String name,
    required String email,
    required String initials,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserInitials, initials);
  }

  Future<void> updateSession({
    required String name,
    required String email,
    required String initials,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserInitials, initials);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserInitials);
  }

  Future<({int? userId, String? name, String? email, String? initials})>
      getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    final name = prefs.getString(_keyUserName);
    final email = prefs.getString(_keyUserEmail);
    final initials = prefs.getString(_keyUserInitials);
    return (userId: userId, name: name, email: email, initials: initials);
  }

  Future<bool> isLoggedIn() async {
    final session = await getSession();
    return session.userId != null;
  }
}

final authPreferences = AuthPreferences();
