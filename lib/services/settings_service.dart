import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsappSettings {
  final String apiServer;
  final String apiToken;
  final String senderPhone;

  const WhatsappSettings({
    required this.apiServer,
    required this.apiToken,
    required this.senderPhone,
  });

  factory WhatsappSettings.fromMap(Map<String, dynamic>? data) {
    return WhatsappSettings(
      apiServer:
          (data?['api_server'] as String?)?.trim().isNotEmpty == true
          ? (data?['api_server'] as String).trim()
          : 'https://api.fonnte.com/send',
      apiToken: (data?['api_token'] as String?)?.trim() ?? '',
      senderPhone: (data?['sender_phone'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'api_server': apiServer.trim(),
      'api_token': apiToken.trim(),
      'sender_phone': senderPhone.trim(),
    };
  }
}

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<double> getIuranAmount() async {
    final doc = await _firestore.collection('settings').doc('iuran').get();

    if (!doc.exists) {
      return 55000;
    }

    final data = doc.data();
    return (data?['iuran_amount'] as num?)?.toDouble() ?? 50000;
  }

  Future<void> updateIuranAmount(double amount) async {
    await _firestore.collection('settings').doc('iuran').set({
      'iuran_amount': amount,
    }, SetOptions(merge: true));
  }

  Future<WhatsappSettings> getWhatsappSettings() async {
    final doc = await _firestore.collection('settings').doc('whatsapp').get();
    return WhatsappSettings.fromMap(doc.data());
  }

  Future<void> updateWhatsappSettings(WhatsappSettings settings) async {
    await _firestore.collection('settings').doc('whatsapp').set(
      settings.toMap(),
      SetOptions(merge: true),
    );
  }
}
