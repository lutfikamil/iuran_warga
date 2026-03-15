import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_warga_page.dart';
import 'detail_warga_page.dart';
import '../../services/export_import_service.dart';
import '../../models/warga_model.dart'; // Pastikan path ini benar

class WargaPage extends StatefulWidget {
  const WargaPage({super.key});

  @override
  State<WargaPage> createState() => _WargaPageState();
}

class _WargaPageState extends State<WargaPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<DocumentSnapshot> _allWargaDocs =
      []; // Untuk menyimpan semua dokumen warga

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi untuk menampilkan menu export/import
  void _showExportImportMenu(
    BuildContext context,
    List<DocumentSnapshot> wargaData,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export Excel'),
                onTap: () async {
                  Navigator.pop(bc); // Tutup bottom sheet
                  await ExportImportService.exportWargaToExcel(
                    context,
                    wargaData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export PDF'),
                onTap: () async {
                  Navigator.pop(bc); // Tutup bottom sheet
                  await ExportImportService.exportWargaToPdf(
                    context,
                    wargaData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import Excel'),
                onTap: () {
                  Navigator.pop(bc); // Tutup bottom sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Fitur Import Excel belum diimplementasikan sepenuhnya',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi helper untuk membuat TableRow ---
  // Fungsi ini mirip dengan yang di DetailWargaPage, tapi disesuaikan untuk data warga
  TableRow _buildWargaTableRow(
    List<Widget> cells, {
    Color? backgroundColor,
    TextStyle? textStyle,
    VoidCallback? onTap, // Tambahkan onTap untuk setiap baris
  }) {
    return TableRow(
      decoration: BoxDecoration(color: backgroundColor),
      children: cells.map((cell) {
        return GestureDetector(
          // Gunakan GestureDetector untuk onTap pada sel/baris
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DefaultTextStyle(
              style: textStyle ?? const TextStyle(),
              child: cell,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Warga"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_copy), // Icon untuk export/import
            onPressed: () {
              _showExportImportMenu(context, _allWargaDocs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddWargaPage()),
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
                hintText: 'Cari nama, rumah, HP, atau status...',
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
        stream: FirebaseFirestore.instance.collection("warga").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _allWargaDocs = [];
            return Center(
              child: Text(
                'Terjadi kesalahan: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            _allWargaDocs = [];
            return const Center(child: CircularProgressIndicator());
          }

          _allWargaDocs = snapshot.data!.docs;

          List<DocumentSnapshot> filteredWargaDocs = _allWargaDocs.where((doc) {
            final wargaData = doc.data() as Map<String, dynamic>;
            final nama = wargaData["nama"]?.toLowerCase() ?? '';
            final rumah = wargaData["rumah"]?.toLowerCase() ?? '';
            final hp = wargaData["hp"]?.toLowerCase() ?? '';
            final status = wargaData["status"]?.toLowerCase() ?? '';
            return nama.contains(_searchQuery) ||
                rumah.contains(_searchQuery) ||
                hp.contains(_searchQuery) ||
                status.contains(_searchQuery);
          }).toList();

          if (filteredWargaDocs.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'Tidak ada data warga saat ini.'
                    : 'Tidak ada warga yang cocok dengan "$_searchQuery".',
              ),
            );
          }

          // --- Spreadsheet View dengan Table ---
          return SingleChildScrollView(
            // Tambahkan SingleChildScrollView agar bisa discroll jika kolom terlalu banyak
            scrollDirection:
                Axis.vertical, // Scroll vertikal untuk seluruh tabel
            child: SingleChildScrollView(
              // SingleChildScrollView untuk scroll horizontal jika tabel terlalu lebar
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FixedColumnWidth(50), // No
                  1: FixedColumnWidth(150), // Nama
                  2: FixedColumnWidth(80), // Rumah
                  3: FixedColumnWidth(120), // HP
                  4: FixedColumnWidth(100), // Status
                },
                children: [
                  // Header Tabel
                  _buildWargaTableRow(
                    const [
                      Text("No", textAlign: TextAlign.center),
                      Text("Nama", textAlign: TextAlign.left),
                      Text("Rumah", textAlign: TextAlign.center),
                      Text("HP", textAlign: TextAlign.left),
                      Text("Status", textAlign: TextAlign.center),
                    ],
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1), // Warna header
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  // Data Warga
                  ...List.generate(filteredWargaDocs.length, (index) {
                    final wargaDoc = filteredWargaDocs[index];
                    final warga = WargaModel.fromMap(
                      wargaDoc.id,
                      wargaDoc.data() as Map<String, dynamic>,
                    );

                    return _buildWargaTableRow(
                      [
                        Text(
                          (index + 1).toString(),
                          textAlign: TextAlign.center,
                        ),
                        Text(warga.nama, textAlign: TextAlign.left),
                        Text(warga.rumah, textAlign: TextAlign.center),
                        Text(warga.hp, textAlign: TextAlign.left),
                        Text(warga.status, textAlign: TextAlign.center),
                      ],
                      backgroundColor: index.isEven
                          ? Colors.grey.shade50
                          : Colors.white, // Zebra stripe
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetailWargaPage(wargaId: wargaDoc.id),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
