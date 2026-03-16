import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'log_service.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
);

class PemasukanService {
  final FirebaseFirestore _firestore;

  PemasukanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  Future<void> addPemasukan({
    required DateTime tanggal,
    required double jumlah,
    required String dari,
    required String penerima,
    String? keterangan,
  }) async {
    _log('Menambahkan pemasukan umum baru...');
    try {
      await _firestore.collection('transaksi').add({
        'tanggal': Timestamp.fromDate(tanggal),
        'jenis': 'masuk',
        'jumlah': jumlah,
        'dari': dari,
        'penerima': penerima,
        'keterangan': keterangan ?? '',
        'sumberPemasukan': 'umum',
        'statusBendahara': 'menunggu',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _log('Pemasukan umum berhasil ditambahkan.');
      await LogService().logEvent(
        action: 'tambah_pemasukan',
        target: 'transaksi',
        detail: 'Tambah pemasukan umum sebesar Rp ${jumlah.toStringAsFixed(0)} dari $dari',
      );
    } catch (e, st) {
      _log('Gagal menambahkan pemasukan umum: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updatePemasukan({
    required String id,
    required DateTime tanggal,
    required double jumlah,
    required String dari,
    required String penerima,
    String? keterangan,
  }) async {
    _log('Memperbarui pemasukan umum ID: $id');
    try {
      await _firestore.collection('transaksi').doc(id).update({
        'tanggal': Timestamp.fromDate(tanggal),
        'jumlah': jumlah,
        'dari': dari,
        'penerima': penerima,
        'keterangan': keterangan ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _log('Pemasukan umum ID: $id berhasil diperbarui.');
      await LogService().logEvent(
        action: 'update_pemasukan',
        target: 'transaksi',
        detail: 'Update pemasukan id=$id menjadi Rp ${jumlah.toStringAsFixed(0)}',
      );
    } catch (e, st) {
      _log(
        'Gagal memperbarui pemasukan umum ID: $id: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deletePemasukan(String id) async {
    _log('Menghapus pemasukan umum ID: $id');
    try {
      await _firestore.collection('transaksi').doc(id).delete();
      _log('Pemasukan umum ID: $id berhasil dihapus.');
      await LogService().logEvent(
        action: 'hapus_pemasukan',
        target: 'transaksi',
        detail: 'Hapus pemasukan id=$id',
      );
    } catch (e, st) {
      _log(
        'Gagal menghapus pemasukan umum ID: $id: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
