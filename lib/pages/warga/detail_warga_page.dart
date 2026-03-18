import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/iuran_service.dart';
import '../../services/log_service.dart';
import '../../utils/bulan_util.dart';
import 'add_warga_page.dart';

class DetailWargaPage extends StatelessWidget {
  final String wargaId;

  DetailWargaPage({super.key, required this.wargaId});

  final bulanUtil = ListBulanIuran();

  Future<void> _deleteWarga(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Warga"),
        content: const Text("Apakah yakin ingin menghapus warga ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection("warga").doc(wargaId).delete();

      await LogService().logEvent(
        action: 'hapus_warga',
        target: 'warga',
        detail: 'Hapus data warga id=$wargaId',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data warga berhasil dihapus")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e")),
        );
      }
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

  Widget _buildRekapCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String role,
    BuildContext context,
  ) {
    final now = DateTime.now();
    final tahunList = docs.isEmpty ? [now.year] : bulanUtil.getTahunFromIuran(docs);
    final rekap = bulanUtil.buildRekapFromIuran(docs, tahunList);
    final canPay = {
      'admin',
      'ketua',
      'bendahara',
      'sekretaris',
      'petugas',
    }.contains(role);

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
                  ...tahunList.map((tahun) => DataColumn(label: Text('$tahun'))),
                  if (canPay) const DataColumn(label: Text("Aksi")),
                ],
                rows: bulanUtil.bulanList.map((bulan) {
                  final unpaidDocs = docs.where((doc) {
                    final data = doc.data();
                    return data['bulan'] == bulan && data['status'] != 'lunas';
                  }).toList()
                    ..sort(
                      (a, b) => ((a.data()['tahun'] as int?) ?? now.year)
                          .compareTo((b.data()['tahun'] as int?) ?? now.year),
                    );

                  return DataRow(
                    cells: [
                      DataCell(Text(bulan)),
                      ...tahunList.map((tahun) {
                        final value = rekap[bulan]?[tahun];
                        final isLunas = value != null && value != 'Belum';
                        return DataCell(
                          value == null
                              ? const Text(
                                  'Belum',
                                  style: TextStyle(color: Colors.red),
                                )
                              : Text(
                                  value,
                                  style: TextStyle(
                                    color: isLunas ? Colors.green : Colors.red,
                                  ),
                                ),
                        );
                      }),
                      if (canPay)
                        DataCell(
                          unpaidDocs.isEmpty
                              ? const Text(
                                  'Lunas',
                                  style: TextStyle(color: Colors.green),
                                )
                              : ElevatedButton(
                                  onPressed: () =>
                                      _handleBayar(context, bulan, unpaidDocs),
                                  child: Text(
                                    unpaidDocs.length > 1
                                        ? 'Bayar (${unpaidDocs.length})'
                                        : 'Bayar',
                                  ),
                                ),
                        ),
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

  Future<void> _handleBayar(
    BuildContext context,
    String bulan,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> unpaidDocs,
  ) async {
    if (unpaidDocs.isEmpty) return;

    final selectedDoc = unpaidDocs.length == 1
        ? unpaidDocs.first
        : await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text('Pilih tunggakan $bulan yang akan dibayar'),
              children: unpaidDocs.map((doc) {
                final tahun = (doc.data()['tahun'] as int?) ?? DateTime.now().year;
                final jumlah = (doc.data()['jumlah'] as num?) ?? 0;
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, doc),
                  child: Text('$bulan $tahun • ${bulanUtil.formatRupiah(jumlah)}'),
                );
              }).toList(),
            ),
          );

    if (selectedDoc == null) return;

    final tahun = (selectedDoc.data()['tahun'] as int?) ?? DateTime.now().year;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Text('Tandai iuran $bulan $tahun sebagai lunas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bayar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await IuranService().bayarIuranWarga(
        wargaId: wargaId,
        bulan: bulan,
        tahun: tahun,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pembayaran iuran $bulan $tahun berhasil.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pembayaran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final wargaRef = FirebaseFirestore.instance.collection('warga').doc(wargaId);
    final iuranRef = FirebaseFirestore.instance
        .collection('iuran')
        .where('wargaId', isEqualTo: wargaId);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Warga')),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([
          wargaRef.get(),
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wargaSnap = snapshot.data![0];
          final wargaData = wargaSnap.data() as Map<String, dynamic>?;
          if (wargaData == null) {
            return const Center(child: Text('Data warga tidak ditemukan.'));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final role = (userData?['role'] ?? 'warga')
                  .toString()
                  .toLowerCase()
                  .trim();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                  final iuranDocs = iuranSnapshot.data!.docs;
                  final totalBayar = iuranDocs.fold<num>(0, (sum, doc) {
                    final data = doc.data();
                    if (data['status'] != 'lunas') return sum;
                    return sum + ((data['jumlah'] as num?) ?? 0);
                  });
                  final totalTransaksiLunas = iuranDocs
                      .where((doc) => doc.data()['status'] == 'lunas')
                      .length;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
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
                                  wargaData['nama'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(height: 30),
                                _buildInfo('Nomor Rumah', wargaData['rumah'] ?? '-'),
                                _buildInfo('No HP', wargaData['hp'] ?? '-'),
                                _buildInfo(
                                  'Status Rumah',
                                  wargaData['status'] ?? '-',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                  'Ringkasan Iuran',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _summaryItem(
                                      'Total Bayar',
                                      bulanUtil.formatRupiah(totalBayar),
                                    ),
                                    _summaryItem(
                                      'Transaksi',
                                      totalTransaksiLunas.toString(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRekapCard(iuranDocs, role, context),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddWargaPage(wargaId: wargaId),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: const Text('Hapus'),
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
          );
        },
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
