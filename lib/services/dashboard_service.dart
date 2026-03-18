import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _db;

  DashboardService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// =========================
  /// 1. JUMLAH WARGA MENUNGGAK (UNIK PER ORANG)
  /// =========================
  Future<int> jumlahWargaMenunggak() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snap = await _db
        .collection("iuran")
        .where("status", isEqualTo: "belum")
        .where("jatuhTempo", isLessThan: now)
        .get();

    // pakai Set supaya tidak double orang
    final Set<String> wargaIds = {};

    for (var doc in snap.docs) {
      final wargaId = doc["wargaId"];
      if (wargaId != null) {
        wargaIds.add(wargaId);
      }
    }

    return wargaIds.length;
  }

  /// =========================
  /// 2. TOTAL NOMINAL TUNGGAKAN
  /// =========================
  Future<int> totalNominalTunggakan() async {
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

  /// =========================
  /// 3. TOTAL WARGA AKTIF
  /// =========================
  Future<int> totalWargaAktif() async {
    final snap = await _db
        .collection("warga")
        .where("status", whereIn: ["Dihuni", "Sewa"])
        .count()
        .get();

    return snap.count ?? 0;
  }

  /// =========================
  /// 4. TOTAL SALDO KAS
  /// =========================
  Future<int> totalSaldoKas() async {
    final pemasukanSnap = await _db
        .collection("transaksi")
        .where("jenis", isEqualTo: "masuk")
        .get();

    final pengeluaranSnap = await _db
        .collection("transaksi")
        .where("jenis", isEqualTo: "keluar")
        .get();

    int totalMasuk = 0;
    int totalKeluar = 0;

    for (var doc in pemasukanSnap.docs) {
      totalMasuk += (doc["jumlah"] ?? 0) as int;
    }

    for (var doc in pengeluaranSnap.docs) {
      totalKeluar += (doc["jumlah"] ?? 0) as int;
    }

    return totalMasuk - totalKeluar;
  }

  /// PRESENSTASE KEPATUHAN WARGA
  Future<double> persentaseKetaatan() async {
    final totalWarga = await totalWargaAktif();
    final wargaNunggak = await jumlahWargaMenunggak();

    if (totalWarga == 0) return 0;

    final taat = totalWarga - wargaNunggak;

    return (taat / totalWarga) * 100;
  }

  Future<Map<String, dynamic>> getStatistikKetaatan() async {
    final totalWarga = await totalWargaAktif();
    final wargaNunggak = await jumlahWargaMenunggak();

    final wargaTaat = totalWarga - wargaNunggak;
    final persen = totalWarga == 0 ? 0 : (wargaTaat / totalWarga) * 100;

    return {
      "total": totalWarga,
      "nunggak": wargaNunggak,
      "taat": wargaTaat,
      "persen": persen,
    };
  }
}
