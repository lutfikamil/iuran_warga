import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_warga_page.dart';
import '../../services/log_service.dart';
import '../../utils/list_waktu_iuran_util.dart';

class DetailWargaPage extends StatelessWidget {
  final String wargaId;

  DetailWargaPage({super.key, required this.wargaId});
  final waktuUtil = ListWaktuIuran();
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

      await LogService().logEvent(
        action: 'hapus_warga',
        target: 'warga',
        detail: 'Hapus data warga id=$wargaId',
      );
     if (!context.mounted) return;
      {
        Navigator.pop(context);
        if (!context.mounted) return;
      }
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

  Widget buildRekapCard(List<QueryDocumentSnapshot> docs) {
    final tahunList = waktuUtil.getTahun(docs);

    final rekap = waktuUtil.buildRekap(docs, tahunList);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Rekap Pembayaran",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text("Bulan")),

                  ...tahunList.map(
                    (t) => DataColumn(label: Text(t.toString())),
                  ),
                ],

                rows: waktuUtil.bulanList.map((bulan) {
                  return DataRow(
                    cells: [
                      DataCell(Text(bulan)),

                      ...tahunList.map((tahun) {
                        final value = rekap[bulan]?[tahun];

                        if (value == null) {
                          return const DataCell(
                            Text("Belum", style: TextStyle(color: Colors.red)),
                          );
                        }

                        return DataCell(
                          Text(
                            value,
                            style: const TextStyle(color: Colors.green),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wargaRef = FirebaseFirestore.instance
        .collection("warga")
        .doc(wargaId);

    final iuranRef = FirebaseFirestore.instance
        .collection("transaksi")
        .where("jenis", isEqualTo: "masuk")
        .where("sumberPemasukan", isEqualTo: "iuran")
        .where("wargaId", isEqualTo: wargaId)
        .orderBy("tanggal", descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Warga")),
      body: FutureBuilder<DocumentSnapshot>(
        future: wargaRef.get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat warga: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = snapshot.data!.data();
          if (rawData == null) {
            return const Center(child: Text('Data warga tidak ditemukan.'));
          }

          final data = rawData as Map<String, dynamic>;
          final nama = data["nama"] ?? "-";
          final rumah = data["rumah"] ?? "-";
          final hp = data["hp"] ?? "-";
          final status = data["status"] ?? "-";
          return StreamBuilder<QuerySnapshot>(
            stream: iuranRef.snapshots(),
            builder: (context, iuranSnapshot) {
              if (iuranSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat riwayat pembayaran: ${iuranSnapshot.error}',
                  ),
                );
              }

              if (!iuranSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final iuranDocs = iuranSnapshot.data!.docs.toList()
                ..sort((a, b) {
                  final ta =
                      (a.data() as Map<String, dynamic>)["tanggal"]
                          as Timestamp?;
                  final tb =
                      (b.data() as Map<String, dynamic>)["tanggal"]
                          as Timestamp?;
                  return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
                    ta?.millisecondsSinceEpoch ?? 0,
                  );
                });

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
                                      waktuUtil.formatRupiah(totalBayar),
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
                            buildRekapCard(iuranDocs),
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
