import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_card.dart';

class LaporanGlobalPage extends StatelessWidget {
  const LaporanGlobalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laporan Global")),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection("pembayaran").snapshots(),

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          int total = 0;

          for (var d in docs) {
            total += (d["jumlah"] ?? 0) as int;
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
                  title: "Total Kas",
                  value: "Rp $total",
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
