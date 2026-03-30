import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/iuran_service.dart';
import '../../utils/bulan_util.dart';
import 'add_warga_page.dart';
import 'mutasi_warga_page.dart';

class DetailWargaPage extends StatelessWidget {
  final String wargaId;
  final bool showAppBar; // Tambahkan variabel ini

  DetailWargaPage({
    super.key,
    required this.wargaId,
    this.showAppBar = true, // Default true agar halaman lain tidak error
  });

  final bulanUtil = ListBulanIuran();

  Future<Map<String, dynamic>> _loadInitialData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User belum login');

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

  @override
  Widget build(BuildContext context) {
    // Kita buat isi konten utamanya di sini
    Widget mainContent = FutureBuilder<Map<String, dynamic>>(
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
          return const Center(child: Text('Data tidak ditemukan'));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('iuran')
              .where('wargaId', isEqualTo: wargaId)
              .snapshots(),
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
                  _actionButtons(context, wargaData, role),
                ],
              ),
            );
          },
        );
      },
    );

    // Jika showAppBar false (dipanggil dari Profile),
    // langsung kembalikan konten tanpa Scaffold & AppBar
    if (!showAppBar) {
      return mainContent;
    }

    // Jika showAppBar true (dipanggil normal), bungkus dengan Scaffold
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Warga')),
      body: mainContent,
    );
  }

  // --- Widget Helper tetap sama (Copy-Paste dari kode lama Anda) ---
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
            _info('HP', data['noHpPenghuni']),
            _info('Status', data['status']),
            _info('Iuran Aktif', data['iuranAktif'] == true ? 'Ya' : 'Tidak'),
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
      'sekretaris',
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
            const Text(
              'Rekap Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Bulan')),
                  ...tahunList.map((t) => DataColumn(label: Text('$t'))),
                  if (canPay) const DataColumn(label: Text('Aksi')),
                ],
                rows: bulanUtil.bulanList.map((bulan) {
                  final bulanDocs = docs
                      .where((d) => d.data()['bulan'] == bulan)
                      .toList();

                  final unpaid = bulanDocs
                      .where((d) => d.data()['status'] != 'lunas')
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
                          bulanDocs.isEmpty
                              ? const Text(
                                  'Belum',
                                  style: TextStyle(color: Colors.grey),
                                )
                              : unpaid.isEmpty
                              ? const Text(
                                  'Lunas',
                                  style: TextStyle(color: Colors.green),
                                )
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
    // 🔹 KONFIRMASI DULU
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Text('Yakin ingin bayar iuran $bulan $tahun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Bayar'),
          ),
        ],
      ),
    ); // 🔹 Jika user batal
    if (confirm != true) return;
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

  Widget _actionButtons(
    BuildContext context,
    Map<String, dynamic> wargaData,
    String role,
  ) {
    if (role == 'warga') {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
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
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Mutasi'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MutasiWargaPage(
                wargaId: wargaId,
                nama: (wargaData['nama'] ?? '').toString(),
                rumah: (wargaData['rumah'] ?? '').toString(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }

  Widget _summary(String label, String value) {
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
