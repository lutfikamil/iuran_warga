import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/bulan_util.dart';

/// Legacy wrapper untuk data pembayaran.
///
/// Saat ini seluruh alur kas disatukan di koleksi `transaksi`.
/// Service ini dipertahankan agar kompatibel dengan pemanggilan lama.
class PembayaranService {
  final collection = FirebaseFirestore.instance.collection('transaksi');

  Future<void> tambahPembayaran(Map<String, dynamic> data) async {
    final now = DateTime.now();
    final String bulan = data['bulanIuran'];
    final int tahun = data['tahunIuran'];
    final bulanList = ListBulanIuran().bulanList;
    final int bulanIndex = bulanList.indexOf(bulan) + 1;
    final payload = <String, dynamic>{
      ...data,
      'jenis': data['jenis'] ?? 'masuk',
      'sumberPemasukan': data['sumberPemasukan'] ?? 'iuran',
      'bulanIuran': data['bulanIuran'],
      'tahunIuran': data['tahunIuran'],
      'tanggal': data['tanggal'] ?? Timestamp.fromDate(now),
      "jatuhTempo": Timestamp.fromDate(DateTime(tahun, bulanIndex, 10)),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
