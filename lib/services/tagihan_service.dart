// File: lib/services/tagihan_service.dart (MODIFIED)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

class TagihanService {
  final FirebaseFirestore _firestore;

  TagihanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  Future<void> generateTagihan(String bulan, int tahun) async {
    final existingTagihan = await _firestore
        .collection("tagihan")
        .where("bulan", isEqualTo: bulan)
        .where("tahun", isEqualTo: tahun)
        .limit(1)
        .get();

    if (existingTagihan.docs.isNotEmpty) {
      throw Exception("Tagihan $bulan $tahun sudah pernah dibuat");
    }

    final wargaSnapshot = await _firestore.collection("warga").get();

    final iuranAmount = await SettingsService().getIuranAmount();

    WriteBatch batch = _firestore.batch();
    int counter = 0;

    for (var warga in wargaSnapshot.docs) {
      final ref = _firestore.collection("tagihan").doc();

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

  Future<void> generateTagihanSetahun(int tahun) async {
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
        await generateTagihan(bulan, tahun);
      } catch (_) {
        // jika sudah ada, skip
      }
    }
  }

  /// Memproses pembayaran tagihan.
  /// Menggunakan Firestore transaction untuk memastikan atomisitas operasi,
  /// dan menulis ke koleksi 'transaksi'.
  Future<void> bayar(String tagihanId) async {
    _log('Memulai proses pembayaran untuk tagihan ID: $tagihanId');
    try {
      await _firestore.runTransaction((transaction) async {
        final tagihanRef = _firestore.collection("tagihan").doc(tagihanId);
        final tagihanSnapshot = await transaction.get(tagihanRef);

        if (!tagihanSnapshot.exists) {
          throw Exception("Tagihan dengan ID $tagihanId tidak ditemukan.");
        }

        final data = tagihanSnapshot.data()!;
        if (data["status"] == "lunas") {
          throw Exception("Tagihan sudah lunas.");
        }

        final wargaRef = _firestore.collection("warga").doc(data["wargaId"]);
        final wargaSnapshot = await transaction.get(wargaRef);
        final wargaData = wargaSnapshot.data();
        final String namaWarga = wargaData?['nama'] ?? 'Warga Tidak Diketahui';
        final String rumahWarga = wargaData?['rumah'] ?? '-';
        final String dariKeterangan = '$namaWarga (Rumah $rumahWarga)';

        // Tambahkan record transaksi masuk ke koleksi 'transaksi'
        final transaksiRef = _firestore.collection("transaksi").doc();
        transaction.set(transaksiRef, {
          "tanggal": FieldValue.serverTimestamp(),
          "jenis": "masuk",
          "sumberPemasukan": "iuran",
          "wargaId": data["wargaId"],
          "bulanTagihan": data["bulan"],
          "tahunTagihan": data["tahun"],
          "jumlah": data["jumlah"],
          "dari": dariKeterangan,
          "penerima": "Bendahara", // Atau ambil dari session user yang login
          "keterangan":
              "Pembayaran iuran bulan ${data["bulan"]} untuk ID Tagihan: $tagihanId",
          "statusBendahara": "menunggu", // Status awal saat dimasukkan
          "referensiId": tagihanId, // Opsional: referensi ke tagihan aslinya
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Update status tagihan menjadi lunas
        transaction.update(tagihanRef, {
          "status": "lunas",
          "updatedAt": FieldValue.serverTimestamp(),
          "tanggalBayar": FieldValue.serverTimestamp(),
        });
      });
      _log('Pembayaran tagihan ID: $tagihanId berhasil.');
      await LogService().logEvent(
        action: 'pembayaran_iuran',
        target: 'tagihan',
        detail: 'Pembayaran berhasil untuk tagihanId=$tagihanId',
      );
    } catch (e, st) {
      _log(
        'Gagal memproses pembayaran untuk tagihan ID: $tagihanId: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
