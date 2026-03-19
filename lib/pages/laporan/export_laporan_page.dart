import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportLaporanPage extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final String filterType;
  final DateTime? selectedDate;

  const ExportLaporanPage({
    super.key,
    required this.transactions,
    required this.filterType,
    this.selectedDate,
  });

  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  String get _periodeText {
    if (selectedDate == null) return 'Global';
    return filterType == 'Bulanan'
        ? DateFormat('MMMM yyyy', 'id_ID').format(selectedDate!)
        : DateFormat('yyyy', 'id_ID').format(selectedDate!);
  }

  Future<void> _exportToExcel(BuildContext context) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Laporan'];

    // Header
    sheetObject.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Jenis'),
      TextCellValue('Masuk'),
      TextCellValue('Keluar'),
      TextCellValue('Saldo'),
      TextCellValue('Dari'),
      TextCellValue('Penerima'),
      TextCellValue('Keterangan'),
      TextCellValue('Status'),
    ]);

    // Data
    for (int i = 0; i < transactions.length; i++) {
      final trx = transactions[i];
      final bool isMasuk = trx['jenis'] == 'masuk';
      final num jumlah = trx['jumlah'] ?? 0;
      final DateTime? tanggal = (trx['tanggal'] as Timestamp?)?.toDate();

      sheetObject.appendRow([
        IntCellValue(i + 1),
        TextCellValue(
          tanggal != null ? DateFormat('dd MMM yyyy').format(tanggal) : '-',
        ),
        TextCellValue(isMasuk ? 'Masuk' : 'Keluar'),
        TextCellValue(isMasuk ? formatRupiah(jumlah) : ''),
        TextCellValue(!isMasuk ? formatRupiah(jumlah) : ''),
        TextCellValue(formatRupiah(trx['currentBalance'])),
        TextCellValue(trx['dari']),
        TextCellValue(trx['penerima']),
        TextCellValue(trx['keterangan']),
        TextCellValue(trx['statusBendahara']),
      ]);
    }

    final fileBytes = excel.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan_$_periodeText.xlsx');
    await file.writeAsBytes(fileBytes!);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel tersimpan: ${file.path}')));
    }
  }

  Future<void> _exportToPdf(BuildContext context) async {
    final pdf = pw.Document();
    final tableHeaders = [
      'No',
      'Tanggal',
      'Jenis',
      'Masuk',
      'Keluar',
      'Saldo',
      'Dari',
      'Penerima',
      'Keterangan',
      'Status',
    ];

    final tableData = transactions.map((trx) {
      final bool isMasuk = trx['jenis'] == 'masuk';
      final num jumlah = trx['jumlah'] ?? 0;
      final DateTime? tanggal = (trx['tanggal'] as Timestamp?)?.toDate();
      return [
        (transactions.indexOf(trx) + 1).toString(),
        tanggal != null ? DateFormat('dd MMM yyyy').format(tanggal) : '-',
        isMasuk ? 'Masuk' : 'Keluar',
        isMasuk ? formatRupiah(jumlah) : '',
        !isMasuk ? formatRupiah(jumlah) : '',
        formatRupiah(trx['currentBalance']),
        trx['dari'],
        trx['penerima'],
        trx['keterangan'],
        trx['statusBendahara'],
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Laporan Keuangan - $_periodeText',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan_$_periodeText.pdf');
    await file.writeAsBytes(await pdf.save());

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF tersimpan: ${file.path}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Laporan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Periode: $_periodeText',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.grid_on),
              label: const Text('Export ke Excel (.xlsx)'),
              onPressed: () => _exportToExcel(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export ke PDF (.pdf)'),
              onPressed: () => _exportToPdf(context),
            ),
          ],
        ),
      ),
    );
  }
}
