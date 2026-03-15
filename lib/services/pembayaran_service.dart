import 'package:cloud_firestore/cloud_firestore.dart';

/// Legacy wrapper untuk data pembayaran.
///
/// Saat ini seluruh alur kas disatukan di koleksi `transaksi`.
/// Service ini dipertahankan agar kompatibel dengan pemanggilan lama.
class PembayaranService {
  final collection = FirebaseFirestore.instance.collection('transaksi');

  Future<void> tambahPembayaran(Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      'jenis': data['jenis'] ?? 'masuk',
      'sumberPemasukan': data['sumberPemasukan'] ?? 'iuran',
      'tanggal': data['tanggal'] ?? Timestamp.now(),
      'createdAt': data['createdAt'] ?? Timestamp.now(),
      'updatedAt': data['updatedAt'] ?? Timestamp.now(),
    };

    await collection.add(payload);
  }

  Stream<QuerySnapshot> getPembayaran() {
    return collection.where('sumberPemasukan', isEqualTo: 'iuran').snapshots();
  }

  Future<void> hapusPembayaran(String id) async {
    await collection.doc(id).delete();
  }
}
