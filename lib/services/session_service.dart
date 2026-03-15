import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Future<void> saveLogin(String role) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("isLogin", true);
    await prefs.setString("role", role);
  }

  static Future<bool> isLogin() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool("isLogin") ?? false;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("role");
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }
}
