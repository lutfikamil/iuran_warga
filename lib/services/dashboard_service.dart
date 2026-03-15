import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<int> totalWarga() async {
    final snap = await firestore.collection("warga").get();
    return snap.docs.length;
  }

  Future<int> totalPembayaranBulan(String bulan) async {
    final snap = await firestore
        .collection("transaksi")
        .where("jenis", isEqualTo: "masuk")
        .where("sumberPemasukan", isEqualTo: "iuran")
        .where("bulanTagihan", isEqualTo: bulan)
        .get();

    return snap.docs.length;
  }

  Future<int> totalKas() async {
    final snap = await firestore.collection("transaksi").get();

    num total = 0;

    for (var doc in snap.docs) {
      final data = doc.data();
      final amount = (data["jumlah"] as num?) ?? 0;
      final type = data["jenis"] as String?;

      if (type == 'keluar') {
        total -= amount;
      } else {
        total += amount;
      }
    }

    return total.toInt();
  }
}
