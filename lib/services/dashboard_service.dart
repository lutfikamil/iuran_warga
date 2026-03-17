import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _db;

  DashboardService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// =========================
  /// TOTAL WARGA
  /// =========================
  Future<int> totalWarga() async {
    final snap = await _db.collection("warga").count().get();
    return snap.count ?? 0;
  }

  /// =========================
  /// TOTAL PEMBAYARAN BULAN
  /// =========================
  Future<int> totalPembayaranBulan(String bulan) async {
    final snap = await _db
        .collection("transaksi")
        .where("jenis", isEqualTo: "masuk")
        .where("sumberPemasukan", isEqualTo: "iuran")
        .where("bulanIuran", isEqualTo: bulan)
        .count()
        .get();

    return snap.count ?? 0;
  }

  /// =========================
  /// TOTAL PEMASUKAN
  /// =========================
  Future<int> totalPemasukan() async {
    final snap = await _db
        .collection("transaksi")
        .where("jenis", isEqualTo: "masuk")
        .get();

    int total = 0;

    for (var doc in snap.docs) {
      total += (doc["jumlah"] ?? 0) as int;
    }

    return total;
  }

  /// =========================
  /// TOTAL PENGELUARAN
  /// =========================
  Future<int> totalPengeluaran() async {
    final snap = await _db
        .collection("transaksi")
        .where("jenis", isEqualTo: "keluar")
        .get();

    int total = 0;

    for (var doc in snap.docs) {
      total += (doc["jumlah"] ?? 0) as int;
    }

    return total;
  }

  /// =========================
  /// TOTAL KAS
  /// =========================
  Future<int> totalKas() async {
    final masuk = await totalPemasukan();
    final keluar = await totalPengeluaran();

    return masuk - keluar;
  }

  /// =========================
  /// TOTAL TUNGGAKAN
  /// =========================
  Future<int> wargaBelumBayar() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snap = await _db
        .collection("iuran")
        .where("status", isEqualTo: "belum")
        .where("jatuhTempo", isLessThan: now)
        .get();

    return snap.docs.length;
  }

  Future<int> totalTunggakan() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snap = await _db
        .collection("iuran")
        .where("status", isEqualTo: "belum")
        .where("jatuhTempo", isLessThan: now)
        .get();

    int total = 0;

    for (var doc in snap.docs) {
      total += (doc["jumlah"] ?? 0) as int;
    }

    return total;
  }
}
