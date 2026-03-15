import 'package:cloud_firestore/cloud_firestore.dart';

class PembayaranService {
  final collection = FirebaseFirestore.instance.collection('pembayaran');

  Future<void> tambahPembayaran(Map<String, dynamic> data) async {
    await collection.add(data);
  }

  Stream<QuerySnapshot> getPembayaran() {
    return collection.snapshots();
  }

  Future<void> hapusPembayaran(String id) async {
    await collection.doc(id).delete();
  }
}
