import 'package:shared_preferences/shared_preferences.dart';

/// Manages the logged-in user session via SharedPreferences.
class AuthPreferences {
  static const _keyUserId = 'auth_user_id';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserInitials = 'auth_user_initials';
  static const _keyAccessToken = 'auth_access_token';
  static const _keyUserRole = 'auth_user_role';

  Future<void> saveSession({
    required int userId,
    required String name,
    required String email,
    required String initials,
    String? accessToken,
    String role = 'user',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserInitials, initials);
    await prefs.setString(_keyUserRole, role);
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(_keyAccessToken, accessToken);
    }
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
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserRole);
  }

  Future<
    ({
      int? userId,
      String? name,
      String? email,
      String? initials,
      String? accessToken,
      String? role,
    })
  >
  getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    final name = prefs.getString(_keyUserName);
    final email = prefs.getString(_keyUserEmail);
    final initials = prefs.getString(_keyUserInitials);
    final accessToken = prefs.getString(_keyAccessToken);
    final role = prefs.getString(_keyUserRole) ?? 'user';
    return (
      userId: userId,
      name: name,
      email: email,
      initials: initials,
      accessToken: accessToken,
      role: role,
    );
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<bool> isLoggedIn() async {
    final session = await getSession();
    return session.userId != null;
  }
}

final authPreferences = AuthPreferences();
