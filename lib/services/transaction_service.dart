import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';

class TransactionService {
  final _db = FirebaseFirestore.instance;

  Stream<List<TransactionModel>> streamTransactions({
    String filterType = 'Global',
    DateTime? selectedDate,
  }) {
    Query query = _db.collection('transaksi');

    if (filterType == 'Bulanan' && selectedDate != null) {
      final start = DateTime(selectedDate.year, selectedDate.month, 1);
      final end = DateTime(
        selectedDate.year,
        selectedDate.month + 1,
        0,
        23,
        59,
        59,
      );

      query = query
          .where('tanggal', isGreaterThanOrEqualTo: start)
          .where('tanggal', isLessThanOrEqualTo: end);
    }

    return query.orderBy('tanggal').snapshots().map((snapshot) {
      double balance = 0;
      List<TransactionModel> result = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final jenis = data['jenis'] ?? 'masuk';
        final jumlah = (data['jumlah'] ?? 0).toDouble();

        if (jenis == 'masuk') {
          balance += jumlah;
        } else {
          balance -= jumlah;
        }

        result.add(TransactionModel.fromFirestore(doc.id, data, balance));
      }

      return result;
    });
  }
}
