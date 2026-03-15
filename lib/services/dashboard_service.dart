import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<int> totalWarga() async {
    final snap = await firestore.collection("warga").get();
    return snap.docs.length;
  }

  Future<int> totalPembayaranBulan(String bulan) async {
    final snap = await firestore
        .collection("pembayaran")
        .where("bulan", isEqualTo: bulan)
        .get();

    return snap.docs.length;
  }

  Future<int> totalKas() async {
    final snap = await firestore.collection("pembayaran").get();

    int total = 0;

    for (var doc in snap.docs) {
      total += (doc["jumlah"] as int);
    }

    return total;
  }
}
