import 'package:cloud_firestore/cloud_firestore.dart';

import 'iuran_service.dart';
import 'log_service.dart';
import 'sekertaris_sync_service.dart';
import 'users_service.dart';

class WargaLifecycleService {
  WargaLifecycleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wargaRef =>
      _firestore.collection('warga');
  CollectionReference<Map<String, dynamic>> get _wargaKeluarRef =>
      _firestore.collection('warga_keluar');
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _riwayatRef =>
      _firestore.collection('warga_riwayat');

  Map<String, dynamic> normalizeRumahData(String rumah) {
    final upper = rumah.trim().toUpperCase();
    final huruf = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    final angkaStr = upper.replaceAll(RegExp(r'[^0-9]'), '');
    final angka = int.tryParse(angkaStr) ?? 0;
    final angkaFormatted = angka.toString().padLeft(2, '0');

    return {'rumah': '$huruf$angkaFormatted', 'blok': huruf, 'nomor': angka};
  }

  Future<Map<String, dynamic>> getWargaById(String wargaId) async {
    final snap = await _wargaRef.doc(wargaId).get();
    if (!snap.exists || snap.data() == null) {
      throw Exception('Data warga tidak ditemukan');
    }

    return {'id': snap.id, ...snap.data()!};
  }

  Future<void> pindahRumah({
    required String wargaId,
    required String rumahBaru,
  }) async {
    final warga = await getWargaById(wargaId);
    final rumahLama = (warga['rumah'] ?? '').toString();
    final rumahData = normalizeRumahData(rumahBaru);
    final normalizedRumahBaru = rumahData['rumah'] as String;

    if (normalizedRumahBaru.isEmpty) {
      throw Exception('Nomor rumah baru wajib diisi');
    }

    if (normalizedRumahBaru == rumahLama) {
      throw Exception('Rumah baru sama dengan rumah saat ini');
    }

    await _wargaRef.doc(wargaId).update({
      'rumah': normalizedRumahBaru,
      'blok': rumahData['blok'],
      'nomor': rumahData['nomor'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await upsertUserLogin(
      wargaId: wargaId,
      nama: (warga['nama'] ?? '').toString(),
      rumah: normalizedRumahBaru,
      noHpPenghuni: (warga['noHpPenghuni'] ?? '').toString(),
      role: (warga['role'] ?? 'warga').toString(),
      identifier: _resolveIdentifier(
        (warga['noHpPenghuni'] ?? '').toString(),
        normalizedRumahBaru,
      ),
    );

    await SekertarisSyncService().markRumahKosong(rumahLama);
    await SekertarisSyncService().syncWarga(
      rumah: normalizedRumahBaru,
      nama: (warga['nama'] ?? '').toString(),
      noHpPenghuni: (warga['noHpPenghuni'] ?? '').toString(),
      status: (warga['status'] ?? 'Dihuni').toString(),
    );

    await _riwayatRef.add({
      'wargaId': wargaId,
      'nama': warga['nama'],
      'jenis': 'pindah_rumah',
      'rumahSebelum': rumahLama,
      'rumahSesudah': normalizedRumahBaru,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await LogService().logEvent(
      action: 'mutasi_pindah_rumah',
      target: 'warga',
      detail:
          'Pindah rumah wargaId=$wargaId dari $rumahLama ke $normalizedRumahBaru',
    );
  }

  Future<void> arsipkanWargaKeluar({
    required String wargaId,
    required String statusKeluar,
    bool nonaktifkanIuran = true,
  }) async {
    final warga = await getWargaById(wargaId);
    final usersQuery = await _usersRef
        .where('wargaId', isEqualTo: wargaId)
        .limit(1)
        .get();

    final batch = _firestore.batch();
    final keluarDoc = _wargaKeluarRef.doc(wargaId);

    batch.set(keluarDoc, {
      ...warga,
      'wargaId': wargaId,
      'statusKeluar': statusKeluar,
      'rumahTerakhir': warga['rumah'],
      'nonaktifkanIuran': nonaktifkanIuran,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(_wargaRef.doc(wargaId));

    if (usersQuery.docs.isNotEmpty) {
      batch.set(usersQuery.docs.first.reference, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    await SekertarisSyncService().markRumahKosong(
      (warga['rumah'] ?? '').toString(),
    );

    await _riwayatRef.add({
      'wargaId': wargaId,
      'nama': warga['nama'],
      'jenis': 'keluar_perumahan',
      'statusKeluar': statusKeluar,
      'rumahTerakhir': warga['rumah'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await LogService().logEvent(
      action: 'arsip_warga_keluar',
      target: 'warga_keluar',
      detail: 'Arsipkan wargaId=$wargaId dengan status $statusKeluar',
    );
  }

  Future<String> gantiPemilikRumah({
    required String wargaIdLama,
    required String namaBaru,
    required String hpBaru,
    required String rumah,
    String roleBaru = 'warga',
    String statusHunianBaru = 'Kosong',
    bool iuranAktif = false,
  }) async {
    final rumahData = normalizeRumahData(rumah);
    final normalizedRumah = rumahData['rumah'] as String;

    await arsipkanWargaKeluar(
      wargaId: wargaIdLama,
      statusKeluar: 'ex $normalizedRumah',
      nonaktifkanIuran: true,
    );

    final newDoc = _wargaRef.doc();
    final identifier = _resolveIdentifier(hpBaru, normalizedRumah);

    await newDoc.set({
      'nama': namaBaru.trim(),
      'rumah': normalizedRumah,
      'blok': rumahData['blok'],
      'nomor': rumahData['nomor'],
      'noHpPenghuni': hpBaru.trim(),
      'status': statusHunianBaru,
      'iuranAktif': iuranAktif,
      'role': roleBaru,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await upsertUserLogin(
      wargaId: newDoc.id,
      nama: namaBaru.trim(),
      rumah: normalizedRumah,
      noHpPenghuni: hpBaru.trim(),
      role: roleBaru,
      identifier: identifier,
      newRawPassword: '123456',
    );

    await SekertarisSyncService().syncWarga(
      rumah: normalizedRumah,
      nama: namaBaru.trim(),
      noHpPenghuni: hpBaru.trim(),
      status: statusHunianBaru,
    );

    await _riwayatRef.add({
      'wargaId': newDoc.id,
      'nama': namaBaru.trim(),
      'jenis': 'ganti_pemilik',
      'rumah': normalizedRumah,
      'menggantikanWargaId': wargaIdLama,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await LogService().logEvent(
      action: 'ganti_pemilik_rumah',
      target: 'warga',
      detail:
          'Ganti pemilik rumah $normalizedRumah dari wargaId=$wargaIdLama ke wargaId=${newDoc.id}',
    );

    await IuranService().generateIuranMulaiBulanBerikutnyaUntukWargaBaru(
      wargaId: newDoc.id,
    );

    return newDoc.id;
  }

  String _resolveIdentifier(String hp, String rumah) {
    return hp.trim().isNotEmpty ? hp.trim() : rumah.trim();
  }
}
