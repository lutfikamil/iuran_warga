import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Future<void> saveLogin({
    required String role,
    required String identifier,
    required bool isAdmin,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("isLogin", true);
    await prefs.setString("role", role);
    await prefs.setString("identifier", identifier);
    await prefs.setBool("isAdmin", isAdmin);
  }

  static Future<bool> isLogin() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool("isLogin") ?? false;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("role");
  }

  static Future<String?> getIdentifier() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("identifier");
  }

  static Future<bool> isAdminLogin() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool("isAdmin") ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }
}
