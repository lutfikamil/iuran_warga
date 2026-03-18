import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ListBulanIuran {
  final List<String> bulanList = const [
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

  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  /// Ambil semua tahun dari transaksi
  List<int> getTahun(List<QueryDocumentSnapshot> docs) {
    final Set<int> tahunSet = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final tahun = data["tahunIuran"];

      if (tahun != null) {
        tahunSet.add(tahun);
      }
    }

    final tahunList = tahunSet.toList()..sort();
    return tahunList;
  }

  /// Bangun data rekap
  Map<String, Map<int, String>> buildRekap(
    List<QueryDocumentSnapshot> docs,
    List<int> tahunList,
  ) {
    Map<String, Map<int, String>> result = {};

    for (var bulan in bulanList) {
      result[bulan] = {};
    }

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final bulan = data["bulanIuran"];
      final tahun = data["tahunIuran"];
      final jumlah = data["jumlah"] ?? 0;

      if (bulan != null && tahun != null) {
        result[bulan]?[tahun] = "Lunas\n${formatRupiah(jumlah)}";
      }
    }

    return result;
  }
  List<int> getTahunFromIuran(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Set<int> tahunSet = {};

    for (var doc in docs) {
      final tahun = doc.data()["tahun"];
      if (tahun is int) {
        tahunSet.add(tahun);
      }
    }

    final tahunList = tahunSet.toList()..sort();
    return tahunList;
  }

  Map<String, Map<int, String>> buildRekapFromIuran(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<int> tahunList,
  ) {
    final Map<String, Map<int, String>> result = {
      for (final bulan in bulanList) bulan: {},
    };

    for (final doc in docs) {
      final data = doc.data();
      final bulan = data["bulan"];
      final tahun = data["tahun"];
      final jumlah = (data["jumlah"] as num?) ?? 0;
      final status = data["status"];

      if (bulan is! String || tahun is! int) continue;

      result[bulan]?[tahun] = status == 'lunas'
          ? "Lunas\n${formatRupiah(jumlah)}"
          : "Belum";
    }

    return result;
  }

}

class BulanUtil {
  static const Map<String, int> _bulanMap = {
    "Januari": 1,
    "Februari": 2,
    "Maret": 3,
    "April": 4,
    "Mei": 5,
    "Juni": 6,
    "Juli": 7,
    "Agustus": 8,
    "September": 9,
    "Oktober": 10,
    "November": 11,
    "Desember": 12,
  };

  /// String → int (nama bulan ke angka)
  static int toInt(String? bulan) {
    if (bulan == null) return DateTime.now().month;
    return _bulanMap[bulan] ?? DateTime.now().month;
  }

  /// int → String (angka ke nama bulan)
  static String toStringMonth(int bulan) {
    return _bulanMap.entries
        .firstWhere(
          (e) => e.value == bulan,
          orElse: () => const MapEntry("Tidak diketahui", 0),
        )
        .key;
  }

  /// List semua bulan
  static List<String> get allBulan => _bulanMap.keys.toList();
}
