import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pemasukan_service.dart';
import 'add_pemasukan_page.dart';

class PemasukanPage extends StatefulWidget {
  const PemasukanPage({super.key});

  @override
  State<PemasukanPage> createState() => _PemasukanPageState();
}

class _PemasukanPageState extends State<PemasukanPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const EdgeInsets _tableCellPadding = EdgeInsets.all(8.0);
  static const double _colWidthNo = 40.0;
  static const double _colWidthTanggal = 100.0;
  static const double _colWidthJumlah = 120.0;
  static const double _colWidthDari = 180.0;
  static const double _colWidthPenerima = 120.0;
  static const double _colWidthKeterangan = 220.0;
  static const double _colWidthAksi = 90.0;

  String _formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pemasukan Warga'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus pemasukan warga ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await PemasukanService().deletePemasukan(id);
      if (!mounted) {
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pemasukan warga berhasil dihapus!')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus pemasukan warga: $e')),
      );
    }
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
      children: [
        _buildHeaderCell('No', textAlign: TextAlign.center),
        _buildHeaderCell('Tanggal', textAlign: TextAlign.center),
        _buildHeaderCell('Jumlah', textAlign: TextAlign.right),
        _buildHeaderCell('Sumber', textAlign: TextAlign.left),
        _buildHeaderCell('Penerima', textAlign: TextAlign.left),
        _buildHeaderCell('Keterangan', textAlign: TextAlign.left),
        _buildHeaderCell('Aksi', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildHeaderCell(
    String text, {
    TextAlign textAlign = TextAlign.center,
  }) {
    return Padding(
      padding: _tableCellPadding,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  TableRow _buildDataRow(int index, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final DateTime? tanggal = (data['tanggal'] as Timestamp?)?.toDate();
    final String tanggalFormatted = tanggal != null
        ? DateFormat('dd MMM yyyy').format(tanggal)
        : '-';

    final num jumlah = (data['jumlah'] as num?) ?? 0;
    final String dari = (data['dari'] ?? '-').toString();
    final String penerima = (data['penerima'] ?? '-').toString();
    final String keterangan = (data['keterangan'] ?? '-').toString();

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.shade50 : Colors.white,
      ),
      children: [
        Padding(
          padding: _tableCellPadding,
          child: Text((index + 1).toString(), textAlign: TextAlign.center),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(tanggalFormatted, textAlign: TextAlign.center),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(_formatRupiah(jumlah), textAlign: TextAlign.right),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(dari, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(penerima, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(keterangan, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddPemasukanPage(pemasukanId: doc.id),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(context, doc.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemasukan Warga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPemasukanPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari sumber, penerima, atau keterangan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transaksi')
                  .where('jenis', isEqualTo: 'masuk')
                  .where('sumberPemasukan', isEqualTo: 'umum')
                  .orderBy('tanggal', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // ignore: avoid_print
                  print(snapshot.error);
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final kategoriKas =
                      (data['kategoriKas'] ?? 'warga').toString().toLowerCase();
                  if (kategoriKas == 'musolah') {
                    return false;
                  }
                  final dari = (data['dari'] ?? '').toString().toLowerCase();
                  final penerima = (data['penerima'] ?? '')
                      .toString()
                      .toLowerCase();
                  final keterangan = (data['keterangan'] ?? '')
                      .toString()
                      .toLowerCase();

                  return _searchQuery.isEmpty ||
                      dari.contains(_searchQuery) ||
                      penerima.contains(_searchQuery) ||
                      keterangan.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Tidak ada data pemasukan warga saat ini.'
                          : 'Tidak ada pemasukan warga yang cocok dengan "$_searchQuery".',
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: SizedBox(
                            width:
                                _colWidthNo +
                                _colWidthTanggal +
                                _colWidthJumlah +
                                _colWidthDari +
                                _colWidthPenerima +
                                _colWidthKeterangan +
                                _colWidthAksi,
                            child: Table(
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              columnWidths: const {
                                0: FixedColumnWidth(_colWidthNo),
                                1: FixedColumnWidth(_colWidthTanggal),
                                2: FixedColumnWidth(_colWidthJumlah),
                                3: FixedColumnWidth(_colWidthDari),
                                4: FixedColumnWidth(_colWidthPenerima),
                                5: FixedColumnWidth(_colWidthKeterangan),
                                6: FixedColumnWidth(_colWidthAksi),
                              },
                              children: [
                                _buildHeaderRow(),
                                ...List.generate(
                                  filteredDocs.length,
                                  (index) =>
                                      _buildDataRow(index, filteredDocs[index]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPemasukanPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
