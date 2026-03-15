import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/tagihan_service.dart';

class PembayaranPage extends StatefulWidget {
  const PembayaranPage({super.key});

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

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
    Map<String, dynamic> tagihanData,
    Map<String, dynamic> wargaData,
    String tagihanId,
  ) {
    final status = tagihanData["status"];
    final namaWarga = wargaData["nama"] ?? '-';
    final bulanTagihan = tagihanData["bulan"] ?? '-';
    final jumlahTagihan = tagihanData["jumlah"] ?? '0';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.withOpacity(0.05) : null,
      ),
      children: [
        Padding(padding: _defaultPadding, child: Text((index + 1).toString())),
        Padding(
          padding: _defaultPadding,
          child: Text(wargaData["rumah"] ?? '-'),
        ),
        Padding(padding: _defaultPadding, child: Text(namaWarga)),
        Padding(padding: _defaultPadding, child: Text(bulanTagihan)),
        Padding(padding: _defaultPadding, child: Text("Rp $jumlahTagihan")),
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
                    // Tampilkan dialog konfirmasi
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Konfirmasi Pembayaran'),
                          content: Text(
                            'Anda yakin ingin menandai tagihan bulan "$bulanTagihan" untuk "$namaWarga" sebesar Rp $jumlahTagihan sebagai lunas?',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              // Menggunakan FilledButton untuk aksi positif
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Ya, Bayar'),
                            ),
                          ],
                        );
                      },
                    );

                    // Jika user menekan 'Ya, Bayar'
                    if (confirm == true) {
                      try {
                        await TagihanService().bayar(tagihanId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil!')),
                        );
                      } catch (e) {
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
    return Scaffold(
      appBar: AppBar(title: const Text("Pembayaran Iuran")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("tagihan").snapshots(),
        builder: (context, tagihanSnap) {
          if (tagihanSnap.hasError) {
            return Center(
              child: Text('Terjadi kesalahan: ${tagihanSnap.error}'),
            );
          }
          if (!tagihanSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tagihanDocs = tagihanSnap.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("warga").snapshots(),
            builder: (context, wargaSnap) {
              if (wargaSnap.hasError) {
                return Center(
                  child: Text('Terjadi kesalahan: ${wargaSnap.error}'),
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
              if (tagihanDocs.isEmpty) {
                return const Center(child: Text('Tidak ada data tagihan.'));
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
                          border: TableBorder.all(color: Colors.grey.shade300),
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
                            ...List.generate(tagihanDocs.length, (index) {
                              final tagihanDoc = tagihanDocs[index];
                              final tagihanData =
                                  tagihanDoc.data() as Map<String, dynamic>;
                              final tagihanId = tagihanDoc.id;

                              final String? wargaId = tagihanData["wargaId"];
                              if (wargaId == null ||
                                  !wargaMap.containsKey(wargaId)) {
                                return const TableRow(
                                  children: [
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(
                                        'Data Warga Tidak Ditemukan',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                    Padding(
                                      padding: _defaultPadding,
                                      child: Text(''),
                                    ),
                                  ],
                                );
                              }

                              final Map<String, dynamic> wargaData =
                                  wargaMap[wargaId]!;
                              return _buildDataRow(
                                index,
                                tagihanData,
                                wargaData,
                                tagihanId,
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
    );
  }
}
