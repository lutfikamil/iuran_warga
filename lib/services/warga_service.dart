import 'package:cloud_firestore/cloud_firestore.dart';

class WargaService {

  final col = FirebaseFirestore.instance.collection("warga");

  Stream<QuerySnapshot> getWarga() {
    return col.orderBy("rumah").snapshots();
  }

  Future addWarga(Map<String, dynamic> data) async {
    await col.add(data);
  }

  Future deleteWarga(String id) async {
    await col.doc(id).delete();
  }
}