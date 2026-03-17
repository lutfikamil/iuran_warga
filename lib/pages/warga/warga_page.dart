import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_warga_page.dart';
import 'detail_warga_page.dart';
import '../../services/export_import_service.dart';
import '../../services/iuran_service.dart';
import '../../services/session_service.dart';
import '../../models/warga_model.dart';
import '../../utils/list_waktu_iuran_util.dart';

class WargaPage extends StatefulWidget {
  const WargaPage({super.key});

  @override
  State<WargaPage> createState() => _WargaPageState();
}

class _WargaPageState extends State<WargaPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allWargaDocs = [];
  bool _isWarga = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionService.getRole();
    setState(() {
      _isWarga = role == 'warga';
    });
  }

  int _hitungTunggakan(Map<String, dynamic>? pembayaran) {
    if (pembayaran == null) return DateTime.now().month;

    final now = DateTime.now();
    int tunggakan = 0;

    for (int i = 1; i <= now.month; i++) {
      final isPaid = pembayaran[i.toString()] == true;
      if (!isPaid) {
        tunggakan++;
      }
    }

    return tunggakan;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// =========================
  /// GENERATE IURAN
  /// =========================
  Future<void> generateIuranDialog(BuildContext context) async {
    String? selectedBulan;
    int selectedTahun = DateTime.now().year;
    final waktuUtil = ListWaktuIuran();
    final result = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Generate Iuran"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBulan,
                    hint: const Text("Pilih Bulan"),
                    items: waktuUtil.bulanList.map((bulan) {
                      return DropdownMenuItem(value: bulan, child: Text(bulan));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBulan = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedTahun,
                    items: List.generate(5, (i) {
                      final tahun = DateTime.now().year + i;
                      return DropdownMenuItem(
                        value: tahun,
                        child: Text(tahun.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedTahun = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      "bulan": selectedBulan,
                      "tahun": selectedTahun,
                    });
                  },
                  child: const Text("Generate"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await IuranService().generateIuran(result["bulan"], result["tahun"]);

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Iuran berhasil dibuat")));
  }

  Future<void> generateIuranSetahunDialog(BuildContext context) async {
    int selectedTahun = DateTime.now().year;

    final tahun = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Generate Iuran 1 Tahun"),
          content: DropdownButtonFormField<int>(
            initialValue: selectedTahun,
            items: List.generate(5, (i) {
              final year = DateTime.now().year + i;
              return DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              );
            }),
            onChanged: (value) {
              selectedTahun = value!;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedTahun),
              child: const Text("Generate"),
            ),
          ],
        );
      },
    );

    if (tahun == null) return;

    await IuranService().generateIuranSetahun(tahun);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Iuran 1 tahun ($tahun) berhasil dibuat")),
    );
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
                  Navigator.pop(bc);
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
                  Navigator.pop(bc);
                  await ExportImportService.exportWargaToPdf(
                    context,
                    wargaData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import Excel'),
                onTap: () async {
                  Navigator.pop(bc);
                  await ExportImportService.importWargaFromExcel(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi helper untuk membuat TableRow ---
  TableRow _buildWargaTableRow(
    List<Widget> cells, {
    Color? backgroundColor,
    TextStyle? textStyle,
    VoidCallback? onTap,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: backgroundColor),
      children: cells.map((cell) {
        return GestureDetector(
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
          // Hanya admin/petugas yang bisa generate & export import
          if (!_isWarga) ...[
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: "Generate 1 Tahun",
              onPressed: () => generateIuranSetahunDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Generate Iuran",
              onPressed: () => generateIuranDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.file_copy),
              tooltip: "Export / Import",
              onPressed: () => _showExportImportMenu(context, _allWargaDocs),
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

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FixedColumnWidth(50), // No
                  1: FixedColumnWidth(150), // Nama
                  2: FixedColumnWidth(80), // Rumah
                  3: FixedColumnWidth(120), // HP
                  4: FixedColumnWidth(100), // Status
                  5: FixedColumnWidth(100), // Tunggakan
                },
                children: [
                  _buildWargaTableRow(
                    const [
                      Text("No", textAlign: TextAlign.center),
                      Text("Nama", textAlign: TextAlign.center),
                      Text("Rumah", textAlign: TextAlign.center),
                      Text("HP", textAlign: TextAlign.center),
                      Text("Status", textAlign: TextAlign.center),
                      Text("Tunggakan", textAlign: TextAlign.center),
                    ],
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  ...List.generate(filteredWargaDocs.length, (index) {
                    final wargaDoc = filteredWargaDocs[index];
                    final warga = WargaModel.fromMap(
                      wargaDoc.id,
                      wargaDoc.data() as Map<String, dynamic>,
                    );
                    final data = wargaDoc.data() as Map<String, dynamic>;
                    final pembayaran = data['pembayaran'];

                    final jumlahTunggakan = _hitungTunggakan(pembayaran);
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
                        Text(
                          jumlahTunggakan == 0
                              ? "Lunas"
                              : "$jumlahTunggakan bln",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: jumlahTunggakan > 0
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      backgroundColor: index.isEven
                          ? Colors.grey.shade50
                          : Colors.white,
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
