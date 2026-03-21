import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/session_service.dart';

class KeuanganMusolahPage extends StatefulWidget {
  const KeuanganMusolahPage({super.key});

  @override
  State<KeuanganMusolahPage> createState() => _KeuanganMusolahPageState();
}

class _KeuanganMusolahPageState extends State<KeuanganMusolahPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const EdgeInsets tableCellPadding = EdgeInsets.all(8);
  static const double _colWidthNo = 48;
  static const double _colWidthTanggal = 110;
  static const double _colWidthMasuk = 130;
  static const double _colWidthKeluar = 130;
  static const double _colWidthSaldo = 130;
  static const double _colWidthPetugas = 150;
  static const double _colWidthKeterangan = 260;

  String _searchQuery = '';
  bool _isExporting = false;

  bool get _canInputTransaksi {
    final role = (SessionService.getRole() ?? '').toLowerCase();
    return role == 'pengurus_musolah';
  }

  String _formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  String _formatTanggal(Timestamp? timestamp) {
    final tanggal = timestamp?.toDate();
    if (tanggal == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tanggal);
  }

  List<Map<String, dynamic>> _withRunningBalance(List<QueryDocumentSnapshot> docs) {
    double saldo = 0;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['kategoriKas'] ?? '').toString().toLowerCase() == 'musolah';
    }).map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final jenis = (data['jenis'] ?? 'masuk').toString();
      final jumlah = (data['jumlah'] as num?)?.toDouble() ?? 0;

      if (jenis == 'masuk') {
        saldo += jumlah;
      } else {
        saldo -= jumlah;
      }

      return {
        'id': doc.id,
        'tanggal': data['tanggal'] as Timestamp?,
        'jenis': jenis,
        'jumlah': jumlah,
        'petugas': (data['petugas'] ?? '-').toString(),
        'keterangan': (data['keterangan'] ?? '-').toString(),
        'saldo': saldo,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterRows(List<Map<String, dynamic>> rows) {
    if (_searchQuery.isEmpty) return rows;
    return rows.where((row) {
      final tanggal = _formatTanggal(row['tanggal'] as Timestamp?);
      final jumlah = (row['jumlah'] as num).toString();
      final petugas = (row['petugas'] ?? '').toString().toLowerCase();
      final keterangan = (row['keterangan'] ?? '').toString().toLowerCase();
      return tanggal.toLowerCase().contains(_searchQuery) ||
          jumlah.contains(_searchQuery) ||
          petugas.contains(_searchQuery) ||
          keterangan.contains(_searchQuery);
    }).toList();
  }

  Future<void> _showTransactionForm(String jenis) async {
    final jumlahController = TextEditingController();
    final keteranganController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedTanggal = DateTime.now();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickTanggal() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedTanggal,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() => selectedTanggal = picked);
              }
            }

            Future<void> save() async {
              if (!(formKey.currentState?.validate() ?? false) || isSaving) {
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                await FirebaseFirestore.instance.collection('transaksi').add({
                  'tanggal': Timestamp.fromDate(selectedTanggal),
                  'jenis': jenis,
                  'jumlah': double.parse(jumlahController.text.trim()),
                  'petugas': SessionService.getNama(),
                  'keterangan': keteranganController.text.trim(),
                  'kategoriKas': 'musolah',
                  'statusBendahara': 'diterima',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Transaksi ${jenis == 'masuk' ? 'pemasukan' : 'pengeluaran'} musolah berhasil disimpan.',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: Text(
                jenis == 'masuk' ? 'Input Pemasukan Musolah' : 'Input Pengeluaran Musolah',
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Tanggal: ${DateFormat('dd MMM yyyy', 'id_ID').format(selectedTanggal)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: pickTanggal,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: jumlahController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jumlah wajib diisi';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Masukkan nominal yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: SessionService.getNama(),
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Petugas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: keteranganController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Keterangan wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel['Keuangan Musolah'];
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Masuk'),
      TextCellValue('Keluar'),
      TextCellValue('Saldo'),
      TextCellValue('Petugas'),
      TextCellValue('Keterangan'),
    ]);

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final isMasuk = row['jenis'] == 'masuk';
      final jumlah = (row['jumlah'] as num?) ?? 0;
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(_formatTanggal(row['tanggal'] as Timestamp?)),
        TextCellValue(isMasuk ? _formatRupiah(jumlah) : ''),
        TextCellValue(!isMasuk ? _formatRupiah(jumlah) : ''),
        TextCellValue(_formatRupiah((row['saldo'] as num?) ?? 0)),
        TextCellValue((row['petugas'] ?? '-').toString()),
        TextCellValue((row['keterangan'] ?? '-').toString()),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel');
    }

    await FileSaver.instance.saveFile(
      name: 'keuangan_musolah_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _exportToPdf(List<Map<String, dynamic>> rows) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Laporan Keuangan Musolah',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['No', 'Tanggal', 'Masuk', 'Keluar', 'Saldo', 'Petugas', 'Keterangan'],
            data: List.generate(rows.length, (index) {
              final row = rows[index];
              final isMasuk = row['jenis'] == 'masuk';
              final jumlah = (row['jumlah'] as num?) ?? 0;
              return [
                '${index + 1}',
                _formatTanggal(row['tanggal'] as Timestamp?),
                isMasuk ? _formatRupiah(jumlah) : '',
                !isMasuk ? _formatRupiah(jumlah) : '',
                _formatRupiah((row['saldo'] as num?) ?? 0),
                (row['petugas'] ?? '-').toString(),
                (row['keterangan'] ?? '-').toString(),
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await FileSaver.instance.saveFile(
      name: 'keuangan_musolah_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      bytes: Uint8List.fromList(await pdf.save()),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  Future<void> _handleExport(
    List<Map<String, dynamic>> rows,
    Future<void> Function(List<Map<String, dynamic>> rows) exporter,
  ) async {
    if (rows.isEmpty || _isExporting) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      await exporter(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export berhasil dibuat.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export gagal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
      children: const [
        _HeaderCell(label: 'No', align: TextAlign.center),
        _HeaderCell(label: 'Tanggal', align: TextAlign.center),
        _HeaderCell(label: 'Masuk', align: TextAlign.right),
        _HeaderCell(label: 'Keluar', align: TextAlign.right),
        _HeaderCell(label: 'Saldo', align: TextAlign.right),
        _HeaderCell(label: 'Petugas', align: TextAlign.left),
        _HeaderCell(label: 'Keterangan', align: TextAlign.left),
      ],
    );
  }

  TableRow _buildDataRow(int index, Map<String, dynamic> row) {
    final isMasuk = row['jenis'] == 'masuk';
    final jumlah = (row['jumlah'] as num?) ?? 0;
    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.shade50 : Colors.white,
      ),
      children: [
        _DataCell(text: '${index + 1}', align: TextAlign.center),
        _DataCell(text: _formatTanggal(row['tanggal'] as Timestamp?), align: TextAlign.center),
        _DataCell(text: isMasuk ? _formatRupiah(jumlah) : '-', align: TextAlign.right),
        _DataCell(text: !isMasuk ? _formatRupiah(jumlah) : '-', align: TextAlign.right),
        _DataCell(text: _formatRupiah((row['saldo'] as num?) ?? 0), align: TextAlign.right),
        _DataCell(text: (row['petugas'] ?? '-').toString()),
        _DataCell(text: (row['keterangan'] ?? '-').toString()),
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
        title: const Text('Keuangan Musolah'),
        actions: [
          if (_canInputTransaksi)
            PopupMenuButton<String>(
              tooltip: 'Transaksi',
              onSelected: _showTransactionForm,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'masuk', child: Text('Pemasukan')),
                PopupMenuItem(value: 'keluar', child: Text('Pengeluaran')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz),
                    SizedBox(width: 6),
                    Text('Transaksi'),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transaksi')
            .orderBy('tanggal')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = _filterRows(_withRunningBalance(snapshot.data!.docs));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari tanggal, nominal, petugas, atau keterangan...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.trim().toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: rows.isEmpty || _isExporting
                          ? null
                          : () => _handleExport(rows, _exportToExcel),
                      icon: const Icon(Icons.grid_on),
                      label: const Text('Export Excel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: rows.isEmpty || _isExporting
                          ? null
                          : () => _handleExport(rows, _exportToPdf),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada transaksi musolah.'
                              : 'Data tidak ditemukan untuk pencarian "$_searchQuery".',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                                    0: FixedColumnWidth(_colWidthNo),
                                    1: FixedColumnWidth(_colWidthTanggal),
                                    2: FixedColumnWidth(_colWidthMasuk),
                                    3: FixedColumnWidth(_colWidthKeluar),
                                    4: FixedColumnWidth(_colWidthSaldo),
                                    5: FixedColumnWidth(_colWidthPetugas),
                                    6: FixedColumnWidth(_colWidthKeterangan),
                                  },
                                  children: [
                                    _buildHeaderRow(),
                                    ...List.generate(rows.length, (index) => _buildDataRow(index, rows[index])),
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

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _HeaderCell({required this.label, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _KeuanganMusolahPageState.tableCellPadding,
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _DataCell({required this.text, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _KeuanganMusolahPageState.tableCellPadding,
      child: Text(text, textAlign: align),
    );
  }
}
