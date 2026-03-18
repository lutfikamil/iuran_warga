import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return 0;
  }

  final FirebaseFirestore _db;

  DashboardService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// =========================
  /// 1. JUMLAH WARGA BELUM BAYAR (UNIK PER ORANG)
  /// =========================
  Future<int> jumlahWargaMenunggak() async {
    final snap = await _db.collection('iuran').get();

    final Set<String> wargaIds = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final wargaId = data['wargaId']?.toString();

      if (wargaId != null && wargaId.isNotEmpty && _isBelumLunas(data)) {
        wargaIds.add(wargaId);
      }
    }

    return wargaIds.length;
  }

  /// =========================
  /// 2. TOTAL NOMINAL TUNGGAKAN / BELUM BAYAR
  /// =========================
  Future<int> totalNominalTunggakan() async {
    final snap = await _db.collection('iuran').get();

    int total = 0;

    for (var doc in snap.docs) {
      total += _toInt(doc.data()["jumlah"]);
    }

    return total;
  }

  /// =========================
  /// 3. TOTAL WARGA AKTIF
  /// =========================
  Future<int> totalWargaAktif() async {
    final snap = await _db.collection('warga').get();

    return snap.docs.where((doc) => _isWargaAktif(doc.data())).length;
  }

  /// =========================
  /// 4. TOTAL SALDO KAS
  /// =========================
  Future<int> totalSaldoKas() async {
    final transaksiSnap = await _db.collection('transaksi').get();

    int total = 0;

    for (var doc in pemasukanSnap.docs) {
      totalMasuk += _toInt(doc.data()["jumlah"]);
    }

    for (var doc in pengeluaranSnap.docs) {
      totalKeluar += _toInt(doc.data()["jumlah"]);
    }

    return total;
  }

  /// PRESENTASE KEPATUHAN WARGA
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
      'total': totalWarga,
      'nunggak': wargaNunggak,
      'taat': wargaTaat,
      'persen': persen,
    };
  }
}
