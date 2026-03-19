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

  Future<Map<String, dynamic>> _loadInitialData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User belum login");

    final wargaSnap = await FirebaseFirestore.instance
        .collection('warga')
        .doc(wargaId)
        .get();

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return {
      'warga': wargaSnap.data(),
      'role': (userSnap.data()?['role'] ?? 'warga').toString().toLowerCase(),
    };
  }

  Future<void> _deleteWarga(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Warga"),
        content: const Text("Yakin ingin menghapus warga ini?"),
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
      await FirebaseFirestore.instance
          .collection("warga")
          .doc(wargaId)
          .delete();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(wargaId)
          .delete();

      await LogService().logEvent(
        action: 'hapus_warga',
        target: 'warga',
        detail: 'Hapus warga id=$wargaId',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Warga berhasil dihapus")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iuranStream = FirebaseFirestore.instance
        .collection('iuran')
        .where('wargaId', isEqualTo: wargaId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Warga')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadInitialData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wargaData = snapshot.data!['warga'] as Map<String, dynamic>?;
          final role = snapshot.data!['role'] as String;

          if (wargaData == null) {
            return const Center(child: Text("Data tidak ditemukan"));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: iuranStream,
            builder: (context, iuranSnapshot) {
              if (!iuranSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = iuranSnapshot.data!.docs;

              final totalBayar = docs.fold<num>(0, (total, doc) {
                final data = doc.data();
                if (data['status'] != 'lunas') return total;
                return total + ((data['jumlah'] as num?) ?? 0);
              });

              final totalTransaksi = docs
                  .where((e) => e.data()['status'] == 'lunas')
                  .length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _cardWarga(wargaData),
                    const SizedBox(height: 16),
                    _cardSummary(totalBayar, totalTransaksi),
                    const SizedBox(height: 16),
                    _rekapCard(docs, role, context),
                    const SizedBox(height: 20),
                    _actionButtons(context),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _cardWarga(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.person, size: 70),
            const SizedBox(height: 10),
            Text(
              data['nama'] ?? '-',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _info('Rumah', data['rumah']),
            _info('HP', data['hp']),
            _info('Status', data['status']),
          ],
        ),
      ),
    );
  }

  Widget _cardSummary(num total, int transaksi) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summary('Total', bulanUtil.formatRupiah(total)),
            _summary('Transaksi', transaksi.toString()),
          ],
        ),
      ),
    );
  }

  Widget _rekapCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String role,
    BuildContext context,
  ) {
    final canPay = [
      'admin',
      'ketua',
      'bendahara',
      'sekertaris',
      'petugas',
    ].contains(role);

    final now = DateTime.now();
    final tahunList = docs.isEmpty
        ? [now.year]
        : bulanUtil.getTahunFromIuran(docs);
    final rekap = bulanUtil.buildRekapFromIuran(docs, tahunList);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Rekap Pembayaran"),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text("Bulan")),
                  ...tahunList.map((t) => DataColumn(label: Text('$t'))),
                  if (canPay) const DataColumn(label: Text("Aksi")),
                ],
                rows: bulanUtil.bulanList.map((bulan) {
                  final unpaid = docs
                      .where(
                        (d) =>
                            d.data()['bulan'] == bulan &&
                            d.data()['status'] != 'lunas',
                      )
                      .toList();

                  return DataRow(
                    cells: [
                      DataCell(Text(bulan)),
                      ...tahunList.map((tahun) {
                        final val = rekap[bulan]?[tahun];
                        return DataCell(Text(val ?? 'Belum'));
                      }),
                      if (canPay)
                        DataCell(
                          unpaid.isEmpty
                              ? const Text('Lunas')
                              : ElevatedButton(
                                  onPressed: () =>
                                      _handleBayar(context, bulan, unpaid),
                                  child: const Text('Bayar'),
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;

    final doc = docs.first;
    final tahun = doc.data()['tahun'] ?? DateTime.now().year;

    try {
      await IuranService().bayarIuranWarga(
        wargaId: wargaId,
        bulan: bulan,
        tahun: tahun,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Berhasil bayar $bulan $tahun')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _actionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddWargaPage(wargaId: wargaId)),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete),
          label: const Text('Hapus'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => _deleteWarga(context),
        ),
      ],
    );
  }

  Widget _info(String label, dynamic value) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(child: Text(value ?? '-')),
      ],
    );
  }

  Widget _summary(String label, String value) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
