import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_card.dart';

class RekapLaporanPage extends StatelessWidget {
  const RekapLaporanPage({super.key});

  bool _isKasWarga(Map<String, dynamic> data) {
    final kategoriKas = (data['kategoriKas'] ?? 'warga').toString().toLowerCase();
    return kategoriKas.isEmpty || kategoriKas == 'warga';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laporan Global Warga")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("transaksi").snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _isKasWarga(data);
          }).toList();

          num total = 0;

          for (var d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final amount = (data["jumlah"] as num?) ?? 0;
            final jenis = data["jenis"] as String?;

            if (jenis == 'keluar') {
              total -= amount;
            } else {
              total += amount;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                AppCard(
                  title: "Total Transaksi",
                  value: docs.length.toString(),
                  icon: Icons.receipt,
                ),

                AppCard(
                  title: "Total Kas Warga",
                  value: "Rp ${total.toInt()}",
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
