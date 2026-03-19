import 'package:http/http.dart' as http;

class WhatsappService {
  static const String _token = 'Aw8teokbic7V8GT6WdTr';

  static Future<void> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final url = Uri.parse('https://api.fonnte.com/send');

      final response = await http.post(
        url,
        headers: {'Authorization': _token},
        body: {'target': _formatPhone(phone), 'message': message},
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal kirim WA: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error WA: $e');
    }
  }

  /// 🔥 FORMAT NOMOR (WAJIB)
  static String _formatPhone(String phone) {
    String p = phone.trim();

    if (p.startsWith('0')) {
      p = '62${p.substring(1)}';
    }

    if (!p.startsWith('62')) {
      p = '62$p';
    }

    return p;
  }
}
