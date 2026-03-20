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
        'target': _formatPhone(phone),
        'message': message,
      };

      if (settings.senderPhone.isNotEmpty) {
        body['phone'] = _formatPhone(settings.senderPhone);
      }

      final response = await http.post(
        url,
        headers: {'Authorization': settings.apiToken},
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal kirim WA: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error WA: $e');
    }
  }

  static String _formatPhone(String phone) {
    String p = phone.trim();

    if (p.startsWith('0')) {
      p = '+62${p.substring(1)}';
    }

    if (!p.startsWith('+62')) {
      p = '+62$p';
    }

    return p;
  }
}
