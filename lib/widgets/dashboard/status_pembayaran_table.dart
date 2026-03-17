import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/iuran_service.dart'; // Pastikan path ini benar

class StatusPembayaranTable extends StatefulWidget {
  const StatusPembayaranTable({super.key});

  @override
  State<StatusPembayaranTable> createState() => _StatusPembayaranTableState();
}

class _StatusPembayaranTableState extends State<StatusPembayaranTable> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String _searchQuery = ''; // State untuk menyimpan query pencarian
  final TextEditingController _searchController =
      TextEditingController(); // Controller untuk TextField pencarian

  // Konstanta untuk padding dan lebar kolom
  static const EdgeInsets _defaultPadding = EdgeInsets.all(8.0);
  static const double _tableCellWidthNo = 50.0;
  static const double _tableCellWidthRumah = 80.0;
  static const double _tableCellWidthNama = 150.0;
  static const double _tableCellWidthBulan = 90.0;
  static const double _tableCellWidthJumlah = 120.0;
  static const double _tableCellWidthStatus = 80.0;
  static const double _tableCellWidthAksi = 120.0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose(); // Jangan lupa dispose searchController
    super.dispose();
  }

  /// HEADER ROW TABLE
  TableRow _buildHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(color: Colors.blue),
      children: [
        Padding(
          padding: _defaultPadding,
          child: Text("No", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Rumah", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Nama", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Bulan", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Jumlah", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Status", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Aksi", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  /// DATA ROW TABLE
  TableRow _buildDataRow(
    int index,
    Map<String, dynamic> iuranData,
    Map<String, dynamic> wargaData,
    String iuranId,
  ) {
    final status = iuranData["status"];
    final num jumlah = (iuranData["jumlah"] as num?) ?? 0;

    final String formattedJumlah =
        "Rp ${jumlah.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.withValues(alpha: 0.05) : null,
      ),
      children: [
        Padding(padding: _defaultPadding, child: Text((index + 1).toString())),
        Padding(
          padding: _defaultPadding,
          child: Text(wargaData["rumah"] ?? '-'),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text(wargaData["nama"] ?? '-'),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text(iuranData["bulan"] ?? '-'),
        ),
        Padding(padding: _defaultPadding, child: Text(formattedJumlah)),
        Padding(
          padding: _defaultPadding,
          child: status == "lunas"
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.close, color: Colors.red),
        ),
        Padding(
          padding: _defaultPadding,
          child: status == "belum"
              ? ElevatedButton(
                  onPressed: () async {
                    try {
                      await IuranService().bayar(iuranId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membayar: $e')),
                        );
                      }
                    }
                  },
                  child: const Text("Bayar"),
                )
              : const Text("Lunas"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      // Menggunakan Column untuk menempatkan search bar di atas tabel
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Search Bar ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama, rumah, bulan, atau status...',
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
        // --- Tabel Pembayaran ---
        Expanded(
          // Expanded agar tabel bisa mengisi sisa ruang yang tersedia
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("iuran").snapshots(),
            builder: (context, iuranSnap) {
              if (iuranSnap.hasError) {
                return Center(
                  child: Text(
                    'Terjadi kesalahan: ${iuranSnap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!iuranSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              List<DocumentSnapshot> allIuranDocs = iuranSnap.data!.docs;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("warga")
                    .snapshots(),
                builder: (context, wargaSnap) {
                  if (wargaSnap.hasError) {
                    return Center(
                      child: Text(
                        'Terjadi kesalahan: ${wargaSnap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (!wargaSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final wargaDocs = wargaSnap.data!.docs;
                  final wargaMap = {
                    for (var doc in wargaDocs)
                      doc.id: doc.data() as Map<String, dynamic>,
                  };

                  // --- Filter data iuran berdasarkan search query ---
                  List<DocumentSnapshot>
                  filteredIuranDocs = allIuranDocs.where((iuranDoc) {
                    final iuranData = iuranDoc.data() as Map<String, dynamic>;
                    final String? wargaId = iuranData["wargaId"];

                    // Jika wargaId tidak ditemukan, anggap tidak cocok dengan pencarian
                    if (wargaId == null || !wargaMap.containsKey(wargaId)) {
                      return false;
                    }

                    final wargaData = wargaMap[wargaId]!;
                    final namaWarga = wargaData["nama"]?.toLowerCase() ?? '';
                    final rumahWarga = wargaData["rumah"]?.toLowerCase() ?? '';
                    final bulanIuran = iuranData["bulan"]?.toLowerCase() ?? '';
                    final statusIuran =
                        iuranData["status"]?.toLowerCase() ?? '';

                    return namaWarga.contains(_searchQuery) ||
                        rumahWarga.contains(_searchQuery) ||
                        bulanIuran.contains(_searchQuery) ||
                        statusIuran.contains(_searchQuery);
                  }).toList();

                  // Tampilan jika tidak ada data iuran setelah filter
                  if (filteredIuranDocs.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'Tidak ada data iuran.'
                            : 'Tidak ada iuran yang cocok dengan "$_searchQuery".',
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(12),
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
                                0: FixedColumnWidth(_tableCellWidthNo),
                                1: FixedColumnWidth(_tableCellWidthRumah),
                                2: FixedColumnWidth(_tableCellWidthNama),
                                3: FixedColumnWidth(_tableCellWidthBulan),
                                4: FixedColumnWidth(_tableCellWidthJumlah),
                                5: FixedColumnWidth(_tableCellWidthStatus),
                                6: FixedColumnWidth(_tableCellWidthAksi),
                              },
                              children: [
                                _buildHeaderRow(),
                                ...List.generate(filteredIuranDocs.length, (
                                  index,
                                ) {
                                  final iuranDoc = filteredIuranDocs[index];
                                  final iuranData =
                                      iuranDoc.data() as Map<String, dynamic>;
                                  final iuranId = iuranDoc.id;

                                  final String? wargaId = iuranData["wargaId"];
                                  // Kita sudah memfilter di atas, jadi ini seharusnya selalu ada
                                  final Map<String, dynamic> wargaData =
                                      wargaMap[wargaId]!;

                                  return _buildDataRow(
                                    index,
                                    iuranData,
                                    wargaData,
                                    iuranId,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
