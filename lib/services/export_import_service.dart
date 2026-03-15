import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class ExportImportService {
  // Load font secara asinkron
  static pw.Font? _notoSans;
  static Future<pw.Font> _loadNotoSans() async {
    if (_notoSans == null) {
      final fontData = await rootBundle.load(
        "assets/fonts/NotoSans-Regular.ttf",
      );
      _notoSans = pw.Font.ttf(fontData);
    }
    return _notoSans!;
  }

  static pw.Font? _notoSansBold;
  static Future<pw.Font> _loadNotoSansBold() async {
    if (_notoSansBold == null) {
      final fontData = await rootBundle.load("assets/fonts/NotoSans-Bold.ttf");
      _notoSansBold = pw.Font.ttf(fontData);
    }
    return _notoSansBold!;
  }

  // --- Fungsi helper untuk mengunduh file di web ---
  static void _downloadFileWeb(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName; // Nama file untuk diunduh
    html.document.body?.children.add(anchor);
    anchor.click(); // Memicu klik untuk mengunduh
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url); // Membersihkan URL objek
  }

  static Future<void> exportWargaToExcel(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
  ) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Data Warga'];

    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Nama'),
      TextCellValue('Rumah'),
      TextCellValue('HP'),
      TextCellValue('Status'),
    ]);

    for (int i = 0; i < wargaDocs.length; i++) {
      final wargaData = wargaDocs[i].data() as Map<String, dynamic>;
      final nama = wargaData["nama"] ?? '-';
      final rumah = wargaData["rumah"] ?? '-';
      final hp = wargaData["hp"] ?? '-';
      final status = wargaData["status"] ?? '-';
      sheet.appendRow([
        TextCellValue((i + 1).toString()),
        TextCellValue(nama),
        TextCellValue(rumah),
        TextCellValue(hp),
        TextCellValue(status),
      ]);
    }

    List<int>? excelBytes = excel.encode();
    if (excelBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengkodekan data Excel.')),
      );
      return;
    }

    final String fileName =
        'data_warga_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx';

    if (kIsWeb) {
      // --- Logika untuk Web ---
      _downloadFileWeb(
        excelBytes,
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data Excel telah diunduh!')),
      );
    } else {
      // --- Logika untuk Android/iOS (Native) ---
      final Directory tempDir = await getTemporaryDirectory();
      final String path = tempDir.path;
      final File file = File('$path/$fileName');

      try {
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Data Warga');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data Excel siap dibagikan!')),
        );
        await file.delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor dan membagikan Excel: $e')),
        );
      }
    }
  }

  static Future<void> exportWargaToPdf(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
  ) async {
    final pdf = pw.Document();

    // Load custom fonts
    final font = await _loadNotoSans();
    final fontBold = await _loadNotoSansBold();

    final List<List<String>> tableData = [
      ['No', 'Nama', 'Rumah', 'HP', 'Status'],
    ];
    for (int i = 0; i < wargaDocs.length; i++) {
      final wargaData = wargaDocs[i].data() as Map<String, dynamic>;
      tableData.add([
        (i + 1).toString(),
        wargaData["nama"] ?? '-',
        wargaData["rumah"] ?? '-',
        wargaData["hp"] ?? '-',
        wargaData["status"] ?? '-',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Laporan Data Warga',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: tableData[0],
              data: tableData.sublist(1),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(font: font),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final String fileName =
        'data_warga_${DateTime.now().toIso8601String().substring(0, 10)}.pdf';

    if (kIsWeb) {
      // --- Logika untuk Web ---
      _downloadFileWeb(pdfBytes, fileName, 'application/pdf');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan PDF telah diunduh!')),
      );
    } else {
      // --- Logika untuk Android/iOS (Native) ---
      final Directory tempDir = await getTemporaryDirectory();
      final String path = tempDir.path;
      final File file = File('$path/$fileName');

      try {
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Data Warga');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan PDF siap dibagikan!')),
        );
        await file.delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor dan membagikan PDF: $e')),
        );
      }
    }
  }
}
