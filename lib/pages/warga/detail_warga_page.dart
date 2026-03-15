import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_warga_page.dart';

class DetailWargaPage extends StatelessWidget {
  final String wargaId;

  const DetailWargaPage({super.key, required this.wargaId});

  Future<void> _deleteWarga(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Warga"),
        content: const Text("Apakah yakin ingin menghapus warga ini?"),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Hapus"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("warga")
          .doc(wargaId)
          .delete();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data warga berhasil dihapus")),
      );
    }
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0)}";
  }

  @override
  Widget build(BuildContext context) {
    final wargaRef = FirebaseFirestore.instance
        .collection("warga")
        .doc(wargaId);

    final iuranRef = FirebaseFirestore.instance
        .collection("iuran")
        .where("wargaId", isEqualTo: wargaId);

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Warga")),
      body: FutureBuilder<DocumentSnapshot>(
        future: wargaRef.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final nama = data["nama"] ?? "-";
          final rumah = data["rumah"] ?? "-";
          final hp = data["hp"] ?? "-";
          final status = data["status"] ?? "-";
          return StreamBuilder<QuerySnapshot>(
            stream: iuranRef.snapshots(),
            builder: (context, iuranSnapshot) {
              if (!iuranSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final iuranDocs = iuranSnapshot.data!.docs;

              num totalBayar = 0;

              for (var doc in iuranDocs) {
                final data = doc.data() as Map<String, dynamic>;
                totalBayar += data["jumlah"] ?? 0;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    /// PROFIL WARGA
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.person, size: 70),
                            const SizedBox(height: 10),
                            Text(
                              nama,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const Divider(height: 30),

                            _buildInfo("Nomor Rumah", rumah),
                            _buildInfo("No HP", hp),
                            _buildInfo("Status Rumah", status),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// RINGKASAN IURAN
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              "Ringkasan Iuran",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text("Total Bayar"),
                                    const SizedBox(height: 5),
                                    Text(
                                      formatRupiah(totalBayar),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),

                                Column(
                                  children: [
                                    const Text("Transaksi"),
                                    const SizedBox(height: 5),
                                    Text(
                                      iuranDocs.length.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// RIWAYAT PEMBAYARAN
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              "Riwayat Pembayaran",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (iuranDocs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(10),
                                child: Text("Belum ada pembayaran"),
                              ),

                            ...iuranDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              final jumlah = data["jumlah"] ?? 0;
                              final ket = data["keterangan"] ?? "-";

                              Timestamp? ts = data["tanggal"];
                              DateTime? tanggal = ts?.toDate();

                              return ListTile(
                                leading: const Icon(Icons.payments),
                                title: Text(formatRupiah(jumlah)),
                                subtitle: Text("${tanggal ?? ""} | $ket"),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// BUTTON
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddWargaPage(wargaId: wargaId),
                              ),
                            );
                          },
                        ),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text("Hapus"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => _deleteWarga(context),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
