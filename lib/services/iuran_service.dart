// File: lib/services/iuran_service.dart (MODIFIED)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iuran_perumahan/services/session_service.dart';
import 'package:logger/logger.dart';
import 'settings_service.dart';
import 'log_service.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

class IuranService {
  final FirebaseFirestore _firestore;

  IuranService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  Future<void> generateIuran(String bulan, int tahun) async {
    final existingIuran = await _firestore
        .collection("iuran")
        .where("bulan", isEqualTo: bulan)
        .where("tahun", isEqualTo: tahun)
        .limit(1)
        .get();

    if (existingIuran.docs.isNotEmpty) {
      throw Exception("Iuran $bulan $tahun sudah pernah dibuat");
    }

    final wargaSnapshot = await _firestore.collection("warga").get();

    final iuranAmount = await SettingsService().getIuranAmount();

    WriteBatch batch = _firestore.batch();
    int counter = 0;

    for (var warga in wargaSnapshot.docs) {
      final ref = _firestore.collection("iuran").doc();

      batch.set(ref, {
        "wargaId": warga.id,
        "bulan": bulan,
        "tahun": tahun,
        "jumlah": iuranAmount,
        "status": "belum",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      counter++;

      if (counter % 400 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }

    await batch.commit();
  }

  Future<void> generateIuranSetahun(int tahun) async {
    final bulanList = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    for (var bulan in bulanList) {
      try {
        await generateIuran(bulan, tahun);
      } catch (_) {
        // jika sudah ada, skip
      }
    }
  }

  /// Memproses pembayaran iuran.
  /// Menggunakan Firestore transaction untuk memastikan atomisitas operasi,
  /// dan menulis ke koleksi 'transaksi'.
  Future<void> bayar(String iuranId) async {
    _log('Memulai proses pembayaran untuk iuran ID: $iuranId');
    try {
      await _firestore.runTransaction((transaction) async {
        final iuranRef = _firestore.collection("iuran").doc(iuranId);
        final iuranSnapshot = await transaction.get(iuranRef);

        if (!iuranSnapshot.exists) {
          throw Exception("Iuran dengan ID $iuranId tidak ditemukan.");
        }

        final data = iuranSnapshot.data()!;
        if (data["status"] == "lunas") {
          throw Exception("Iuran sudah lunas.");
        }

        final wargaRef = _firestore.collection("warga").doc(data["wargaId"]);
        final wargaSnapshot = await transaction.get(wargaRef);
        final wargaData = wargaSnapshot.data();
        final String namaWarga = wargaData?['nama'] ?? 'Warga Tidak Diketahui';
        final String rumahWarga = wargaData?['rumah'] ?? '-';
        final String dariKeterangan = '$namaWarga (Rumah $rumahWarga)';
        final role = SessionService.getRole();
        //final namaUser = user?["user"] ?? "Unknown";
        final transaksiRef = _firestore.collection("transaksi").doc();
        transaction.set(transaksiRef, {
          "tanggal": FieldValue.serverTimestamp(),
          "jenis": "masuk",
          "sumberPemasukan": "iuran",
          "wargaId": data["wargaId"],
          "bulanIuran": data["bulan"],
          "tahunIuran": data["tahun"],
          "jumlah": data["jumlah"],
          "dari": dariKeterangan,
          "penerima": role, // Ambil dari session user yang login
          "keterangan":
              "Pembayaran iuran bulan ${data["bulan"]} untuk ID Iuran: $iuranId",
          "statusBendahara": "menunggu", // Status awal saat dimasukkan
          "referensiId": iuranId, // Opsional: referensi ke iuran aslinya
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Update status iuran menjadi lunas
        transaction.update(iuranRef, {
          "status": "lunas",
          "updatedAt": FieldValue.serverTimestamp(),
          "tanggalBayar": FieldValue.serverTimestamp(),
        });
      });
      _log('Pembayaran iuran ID: $iuranId berhasil.');
      await LogService().logEvent(
        action: 'pembayaran_iuran',
        target: 'iuran',
        detail: 'Pembayaran berhasil untuk iuranId=$iuranId',
      );
    } catch (e, st) {
      _log(
        'Gagal memproses pembayaran untuk iuran ID: $iuranId: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
