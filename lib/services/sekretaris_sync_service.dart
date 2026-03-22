import 'package:cloud_firestore/cloud_firestore.dart';

class SekretarisSyncService {
  SekretarisSyncService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sekretarisRef =>
      _firestore.collection('data_sekretaris');

  Future<void> syncWarga({
    required String rumah,
    String? nama,
    String? noHpPenghuni,
    String? status,
    String? pemilik,
    String? noHpPemilik,
    String? dihuniOleh,
    String? noKtp,
    String? noKk,
    String? keterangan,
  }) async {
    final normalizedRumah = rumah.trim().toUpperCase();
    if (normalizedRumah.isEmpty) return;

    final existing = await _sekretarisRef
        .where('rumah', isEqualTo: normalizedRumah)
        .limit(1)
        .get();

    final existingData = existing.docs.isNotEmpty
        ? existing.docs.first.data()
        : null;
    final normalizedNama = (nama ?? '').trim();
    final normalizedHpPenghuni = (noHpPenghuni ?? '').trim();
    final normalizedStatus = (status ?? '').trim();
    final resolvedPemilik = (pemilik ?? normalizedNama).trim();
    final resolvedNoHpPemilik = (noHpPemilik ?? normalizedHpPenghuni).trim();
    final resolvedDihuniOleh = (dihuniOleh ?? normalizedNama).trim();
    final resolvedNoKtp = (noKtp ?? existingData?['noKtp'] ?? '')
        .toString()
        .trim();
    final resolvedNoKk = (noKk ?? existingData?['noKk'] ?? '')
        .toString()
        .trim();
    final resolvedKeterangan = (keterangan ?? existingData?['keterangan'] ?? '')
        .toString()
        .trim();

    final data = <String, dynamic>{
      'rumah': normalizedRumah,
      'pemilik': resolvedPemilik,
      'noHpPemilik': resolvedNoHpPemilik,
      'status': normalizedStatus,
      'dihuniOleh': resolvedDihuniOleh,
      'noHpPenghuni': normalizedHpPenghuni,
      'noKtp': resolvedNoKtp,
      'noKk': resolvedNoKk,
      'keterangan': resolvedKeterangan,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.set({
        ...data,
        'no': FieldValue.delete(),
      }, SetOptions(merge: true));
      return;
    }

    await _sekretarisRef.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markRumahKosong(String rumah) async {
    final normalizedRumah = rumah.trim().toUpperCase();
    if (normalizedRumah.isEmpty) return;

    final existing = await _sekretarisRef
        .where('rumah', isEqualTo: normalizedRumah)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) return;

    await existing.docs.first.reference.set({
      'rumah': normalizedRumah,
      'pemilik': '',
      'noHpPemilik': '',
      'status': 'Kosong',
      'dihuniOleh': '',
      'noHpPenghuni': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
