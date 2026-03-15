// File: lib/pages/pengeluaran/pengeluaran_page.dart (Buat file baru)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/pengeluaran_service.dart';
import 'add_pengeluaran_page.dart';

class PengeluaranPage extends StatefulWidget {
  const PengeluaranPage({super.key});

  @override
  State<PengeluaranPage> createState() => _PengeluaranPageState();
}

class _PengeluaranPageState extends State<PengeluaranPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Konfirmasi Hapus ---
  Future<void> _confirmDelete(BuildContext context, String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengeluaran'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus pengeluaran ini?',
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

    if (confirm == true) {
      try {
        await PengeluaranService().deletePengeluaran(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengeluaran berhasil dihapus!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus pengeluaran: $e')),
          );
        }
      }
    }
  }

  // --- Fungsi untuk mengformat Rupiah ---
  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  // --- Konstanta untuk styling tabel ---
  static const EdgeInsets _tableCellPadding = EdgeInsets.all(8.0);
  static const double _colWidthNo = 40.0;
  static const double _colWidthTanggal = 100.0;
  static const double _colWidthJumlah = 100.0;
  static const double _colWidthDari = 120.0;
  static const double _colWidthPenerima = 120.0;
  static const double _colWidthKeterangan = 200.0;
  static const double _colWidthAksi = 100.0;

  /// HEADER ROW TABLE
  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      children: [
        _buildHeaderCell("No", textAlign: TextAlign.center),
        _buildHeaderCell("Tanggal", textAlign: TextAlign.center),
        _buildHeaderCell("Jumlah", textAlign: TextAlign.right),
        _buildHeaderCell("Dari", textAlign: TextAlign.left),
        _buildHeaderCell("Penerima", textAlign: TextAlign.left),
        _buildHeaderCell("Keterangan", textAlign: TextAlign.left),
        _buildHeaderCell("Aksi", textAlign: TextAlign.center),
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

  /// DATA ROW TABLE
  TableRow _buildDataRow(int index, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String pengeluaranId = doc.id;

    final DateTime? tanggal = (data['tanggal'] as Timestamp?)?.toDate();
    final String tanggalFormatted = tanggal != null
        ? DateFormat('dd MMM yyyy').format(tanggal)
        : '-';
    final num jumlah = (data['jumlah'] as num?) ?? 0;
    final String dari = data['dari'] ?? '-';
    final String penerima = data['penerima'] ?? '-';
    final String keterangan = data['keterangan'] ?? '-';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.grey.shade50
            : Colors.white, // Zebra stripe
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
          child: Text(formatRupiah(jumlah), textAlign: TextAlign.right),
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
                          AddPengeluaranPage(pengeluaranId: pengeluaranId),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(context, pengeluaranId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Pengeluaran"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPengeluaranPage(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari jumlah, dari, penerima, atau keterangan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("transaksi")
            .where(
              'jenis',
              isEqualTo: 'keluar',
            ) // Hanya tampilkan transaksi jenis 'keluar'
            .orderBy(
              'tanggal',
              descending: true,
            ) // Urutkan berdasarkan tanggal terbaru
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> allPengeluaranDocs = snapshot.data!.docs;

          // --- Filter data berdasarkan search query ---
          List<DocumentSnapshot>
          filteredPengeluaranDocs = allPengeluaranDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String jumlah = (data['jumlah'] as num?)?.toString() ?? '';
            final String dari = data['dari']?.toLowerCase() ?? '';
            final String penerima = data['penerima']?.toLowerCase() ?? '';
            final String keterangan = data['keterangan']?.toLowerCase() ?? '';

            return jumlah.contains(_searchQuery) ||
                dari.contains(_searchQuery) ||
                penerima.contains(_searchQuery) ||
                keterangan.contains(_searchQuery);
          }).toList();

          if (filteredPengeluaranDocs.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'Tidak ada data pengeluaran saat ini.'
                    : 'Tidak ada pengeluaran yang cocok dengan "$_searchQuery".',
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Padding(
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
                          child: Table(
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
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
                              ...List.generate(filteredPengeluaranDocs.length, (
                                index,
                              ) {
                                return _buildDataRow(
                                  index,
                                  filteredPengeluaranDocs[index],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
