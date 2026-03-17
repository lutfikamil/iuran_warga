import 'package:cloud_firestore/cloud_firestore.dart';

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
      "iuran_amount": amount,
    }, SetOptions(merge: true));
  }
}
