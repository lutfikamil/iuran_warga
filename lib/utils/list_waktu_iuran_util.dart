import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ListWaktuIuran {
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
}
