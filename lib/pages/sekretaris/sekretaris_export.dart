import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class SekretarisExport {
  static const List<String> _dataHeaders = [
    'rumah',
    'pemilik',
    'noHpPemilik',
    'status',
    'dihuniOleh',
    'noHpPenghuni',
    'noKtp',
    'noKk',
    'keterangan',
  ];

  /// EXPORT EXCEL
  static Future<void> exportExcel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['DataSekretaris'];

    sheet.appendRow([
      TextCellValue('no'),
      ..._dataHeaders.map((h) => TextCellValue(h)),
    ]);

    for (var i = 0; i < docs.length; i++) {
      final d = docs[i].data();
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        ..._dataHeaders.map((h) => TextCellValue(d[h]?.toString() ?? '')),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/data_sekretaris.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Export Data Sekretaris');
  }

  /// EXPORT PDF
  static Future<void> exportPdf(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'Data Sekretaris',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const [
              'No',
              'Rumah',
              'Pemilik',
              'No hp',
              'Status',
              'Dihuni oleh',
              'No. Hp',
              'No KTP',
              'No KK',
              'Keterangan',
            ],
            data: docs.asMap().entries.map((entry) {
              final index = entry.key;
              final d = entry.value.data();
              return [
                '${index + 1}',
                ..._dataHeaders.map((h) => d[h]?.toString() ?? ''),
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/data_sekretaris.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Export Data Sekretaris');
  }
}
