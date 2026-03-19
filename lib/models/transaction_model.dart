import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final DateTime? tanggal;
  final String jenis;
  final double jumlah;
  final String dari;
  final String penerima;
  final String keterangan;
  final String statusBendahara;
  final double currentBalance;

  TransactionModel({
    required this.id,
    required this.tanggal,
    required this.jenis,
    required this.jumlah,
    required this.dari,
    required this.penerima,
    required this.keterangan,
    required this.statusBendahara,
    required this.currentBalance,
  });

  factory TransactionModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
    double currentBalance,
  ) {
    return TransactionModel(
      id: id,
      tanggal: (data['tanggal'] as Timestamp?)?.toDate(),
      jenis: data['jenis'] ?? 'masuk',
      jumlah: (data['jumlah'] ?? 0).toDouble(),
      dari: data['dari'] ?? '-',
      penerima: data['penerima'] ?? '-',
      keterangan: data['keterangan'] ?? '-',
      statusBendahara: data['statusBendahara'] ?? 'menunggu',
      currentBalance: currentBalance,
    );
  }
}
