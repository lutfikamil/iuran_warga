import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static SharedPreferences? _prefs;

  /// =========================
  /// INIT (WAJIB DIPANGGIL DI MAIN)
  /// =========================
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// =========================
  /// LOGIN SESSION
  /// =========================
  static Future<void> saveLogin({
    required String role,
    required String identifier,
    required bool isAdmin,
  }) async {
    await _prefs?.setBool("isLogin", true);
    await _prefs?.setString("role", role);
    await _prefs?.setString("identifier", identifier);
    await _prefs?.setBool("isAdmin", isAdmin);
  }

  /// =========================
  /// USER (JSON)
  /// =========================
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs?.setString("user", jsonEncode(user));
  }

  static Map<String, dynamic>? getUser() {
    final data = _prefs?.getString("user");
    if (data == null) return null;
    return jsonDecode(data);
  }

  static String getNama() {
    return getUser()?["nama"] ?? "Unknown";
  }

  static String getUserId() {
    return getUser()?["id"] ?? "";
  }

  /// =========================
  /// GETTER CEPAT (NO AWAIT)
  /// =========================
  static bool isLogin() {
    return _prefs?.getBool("isLogin") ?? false;
  }

  static String? getRole() {
    return _prefs?.getString("role");
  }

  static String? getIdentifier() {
    return _prefs?.getString("identifier");
  }

  static bool isAdminLogin() {
    return _prefs?.getBool("isAdmin") ?? false;
  }

  /// =========================
  /// LOGOUT
  /// =========================
  static Future<void> logout() async {
    await _prefs?.clear();
  }
}
