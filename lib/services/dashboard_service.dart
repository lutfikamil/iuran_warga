import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/bulan_util.dart';

class DashboardService {
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return 0;
  }

  static String _normalizeText(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  static bool _isWargaAktif(Map<String, dynamic> data) {
    final status = _normalizeText(data['status']);
    if (status.isEmpty) return true;
    return status != 'kosong';
  }

  static bool _isBelumLunas(Map<String, dynamic> data) {
    final status = _normalizeText(data['status']);
    return status.isNotEmpty && status != 'lunas';
  }

  static bool _isTunggakanIuran(Map<String, dynamic> data, {DateTime? now}) {
    if (!_isBelumLunas(data)) return false;
    return BulanUtil.isTunggakan(
      bulan: data['bulan']?.toString(),
      tahun: data['tahun'] as int?,
      now: now,
    );
  }

  static bool _isKasWarga(Map<String, dynamic> data) {
    final kategoriKas = _normalizeText(data['kategoriKas']);
    return kategoriKas.isEmpty || kategoriKas == 'warga';
  }

  // Formatter Rupiah ribuan dengan titik
  static String _formatRupiah(int amount) {
    final formatter = NumberFormat.decimalPattern('id_ID');
    return 'Rp ${formatter.format(amount)}';
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
      if (wargaId != null && wargaId.isNotEmpty && _isTunggakanIuran(data)) {
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

    for (final doc in snap.docs) {
      final data = doc.data();
      if (_isTunggakanIuran(data)) {
        total += _toInt(data['jumlah']);
      }
    }
    return total;
  }

  /// Versi string format rupiah
  Future<String> totalNominalTunggakanFormatted() async {
    final total = await totalNominalTunggakan();
    return _formatRupiah(total);
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

    for (final doc in transaksiSnap.docs) {
      final data = doc.data();
      if (!_isKasWarga(data)) continue;

      final jumlah = _toInt(data['jumlah']);
      final jenis = _normalizeText(data['jenis']);

      if (jenis == 'keluar') {
        total -= jumlah;
      } else {
        total += jumlah;
      }
    }
    return total;
  }

  /// Versi string format rupiah
  Future<String> totalSaldoKasFormatted() async {
    final total = await totalSaldoKas();
    return _formatRupiah(total);
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
