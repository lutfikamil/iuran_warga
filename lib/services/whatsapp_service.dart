import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

class WhatsappService {
  static final SettingsService _settingsService = SettingsService();

  static Future<void> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final settings = await _settingsService.getWhatsappSettings();

      if (settings.apiServer.isEmpty || settings.apiToken.isEmpty) {
        throw Exception(
          'Konfigurasi WhatsApp belum lengkap. Isi server API dan token di halaman Pengaturan.',
        );
      }

      final url = Uri.parse(settings.apiServer);
      final body = <String, String>{
        'target': _normalizePhone(phone),
        'message': message,
        'countryCode': '62',
      };

      if (settings.senderPhone.isNotEmpty) {
        body['phone'] = _normalizePhone(settings.senderPhone);
      }

      final response = await http.post(
        url,
        headers: {'Authorization': settings.apiToken},
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final responseBody = response.body.trim();
      if (responseBody.isEmpty) return;

      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['status'] == false) {
        final reason = (decoded['reason'] ?? decoded['detail'] ?? responseBody)
            .toString();
        throw Exception(reason);
      }
    } catch (e) {
      throw Exception('Error WA: $e');
    }
  }

  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      throw Exception('Nomor WhatsApp kosong atau tidak valid.');
    }

    if (digits.startsWith('0')) {
      return digits;
    }

    if (digits.startsWith('62')) {
      return '0${digits.substring(2)}';
    }

    return '0$digits';
  }
}
