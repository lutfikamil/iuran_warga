import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'log_service.dart';

// Inisialisasi Logger
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

class PengeluaranService {
  final FirebaseFirestore _firestore;

  PengeluaranService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
    // Jika menggunakan Firebase Crashlytics
    // if (!kDebugMode && error!= null) {
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false);
    // }
  }

  /// Menambahkan pengeluaran baru ke koleksi 'transaksi'.
  Future<void> addPengeluaran({
    required DateTime tanggal,
    required double jumlah,
    required String dari,
    required String penerima,
    String? keterangan,
  }) async {
    _log('Menambahkan pengeluaran baru...');
    try {
      await _firestore.collection("transaksi").add({
        "tanggal": Timestamp.fromDate(tanggal),
        "jenis": "keluar", // Penting: menandakan jenis transaksi
        "jumlah": jumlah,
        "dari": dari,
        "penerima": penerima,
        "keterangan": keterangan ?? '',
        "statusBendahara": "menunggu", // Status awal
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
      _log('Pengeluaran berhasil ditambahkan.');
      await LogService().logEvent(
        action: 'tambah_pengeluaran',
        target: 'transaksi',
        detail: 'Tambah pengeluaran sebesar Rp ${jumlah.toStringAsFixed(0)} untuk $penerima',
      );
    } catch (e, st) {
      _log('Gagal menambahkan pengeluaran: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Memperbarui pengeluaran yang sudah ada di koleksi 'transaksi'.
  Future<void> updatePengeluaran({
    required String id,
    required DateTime tanggal,
    required double jumlah,
    required String dari,
    required String penerima,
    String? keterangan,
  }) async {
    _log('Memperbarui pengeluaran ID: $id');
    try {
      await _firestore.collection("transaksi").doc(id).update({
        "tanggal": Timestamp.fromDate(tanggal),
        "jumlah": jumlah,
        "dari": dari,
        "penerima": penerima,
        "keterangan": keterangan ?? '',
        "updatedAt": FieldValue.serverTimestamp(),
        // jenis dan statusBendahara tidak diubah di sini
      });
      _log('Pengeluaran ID: $id berhasil diperbarui.');
      await LogService().logEvent(
        action: 'update_pengeluaran',
        target: 'transaksi',
        detail: 'Update pengeluaran id=$id menjadi Rp ${jumlah.toStringAsFixed(0)}',
      );
    } catch (e, st) {
      _log(
        'Gagal memperbarui pengeluaran ID: $id: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Menghapus pengeluaran dari koleksi 'transaksi'.
  Future<void> deletePengeluaran(String id) async {
    _log('Menghapus pengeluaran ID: $id');
    try {
      await _firestore.collection("transaksi").doc(id).delete();
      _log('Pengeluaran ID: $id berhasil dihapus.');
      await LogService().logEvent(
        action: 'hapus_pengeluaran',
        target: 'transaksi',
        detail: 'Hapus pengeluaran id=$id',
      );
    } catch (e, st) {
      _log('Gagal menghapus pengeluaran ID: $id: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  // --- Fungsi Tambahan: Mendapatkan detail pengeluaran ---
  Stream<DocumentSnapshot> getPengeluaranStream(String id) {
    return _firestore.collection("transaksi").doc(id).snapshots();
  }
}
