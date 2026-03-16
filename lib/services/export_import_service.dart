// services/export_import_service.dart

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
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/warga_model.dart';
import 'auth_service.dart';

class ExportImportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // --- Fungsi helper untuk mengunduh file di web (sudah ada) ---
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

  // --- Fungsi Export Excel (sudah ada, tambahkan Tanggal Bergabung) ---
  static Future<void> exportWargaToExcel(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
  ) async {
    try {
      if (wargaDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data warga untuk diekspor.')),
        );
        return;
      }

      final excel = Excel.createExcel();
      final Sheet sheet = excel['Data Warga'];

      // Menulis Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama'),
        TextCellValue('Rumah'),
        TextCellValue('HP'),
        TextCellValue('Status'),
        TextCellValue('Role'), // Tambahkan Role
        TextCellValue('Tanggal Bergabung'), // Tambahkan Tanggal Bergabung
      ]);

      // Menulis Data
      for (int i = 0; i < wargaDocs.length; i++) {
        final wargaData = wargaDocs[i].data() as Map<String, dynamic>;
        final nama = wargaData["nama"] ?? '-';
        final rumah = wargaData["rumah"] ?? '-';
        final hp = wargaData["hp"] ?? '-';
        final status = wargaData["status"] ?? '-';
        final role = wargaData["role"] ?? 'warga'; // Ambil role
        final tanggalBergabung =
            wargaData["tanggalBergabung"] ?? '-'; // Ambil tanggal

        sheet.appendRow([
          TextCellValue((i + 1).toString()),
          TextCellValue(nama),
          TextCellValue(rumah),
          TextCellValue(hp),
          TextCellValue(status),
          TextCellValue(role),
          TextCellValue(tanggalBergabung),
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
          'data_warga_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'; // Format tanggal lebih baik

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
        final Directory? tempDir = await getTemporaryDirectory();
        if (tempDir == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat mengakses direktori penyimpanan.'),
            ),
          );
          return;
        }
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
            SnackBar(
              content: Text('Gagal mengekspor dan membagikan Excel: $e'),
            ),
          );
          debugPrint('Export Excel Error (Native): $e');
        }
      }
    } catch (e, st) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengekspor data: $e')));
      debugPrint('Export Excel Error (General): $e \n $st');
    }
  }

  // --- Fungsi Export PDF (sudah ada) ---
  static Future<void> exportWargaToPdf(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
  ) async {
    final pdf = pw.Document();

    // Load custom fonts
    final font = await _loadNotoSans();
    final fontBold = await _loadNotoSansBold();

    final List<List<String>> tableData = [
      [
        'No',
        'Nama',
        'Rumah',
        'HP',
        'Status',
        'Role',
      ], // Tambahkan Role di header PDF
    ];
    for (int i = 0; i < wargaDocs.length; i++) {
      final wargaData = wargaDocs[i].data() as Map<String, dynamic>;
      tableData.add([
        (i + 1).toString(),
        wargaData["nama"] ?? '-',
        wargaData["rumah"] ?? '-',
        wargaData["hp"] ?? '-',
        wargaData["status"] ?? '-',
        wargaData["role"] ?? 'warga', // Ambil role
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
        'data_warga_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf'; // Format tanggal lebih baik

    if (kIsWeb) {
      // --- Logika untuk Web ---
      _downloadFileWeb(pdfBytes, fileName, 'application/pdf');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan PDF telah diunduh!')),
      );
    } else {
      // --- Logika untuk Android/iOS (Native) ---
      final Directory? tempDir = await getTemporaryDirectory();
      if (tempDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat mengakses direktori penyimpanan.'),
          ),
        );
        return;
      }
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
        debugPrint('Export PDF Error (Native): $e');
      }
    }
  }

  // --- FUNGSI importWargaFromExcel yang direfactor ---
  static Future<void> importWargaFromExcel(BuildContext context) async {
    // Memberikan feedback loading ke user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memulai import data...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemilihan file dibatalkan.')),
        );
        return;
      }

      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      int importedCount = 0;
      List<String> failedRows = []; // Untuk mencatat baris yang gagal
      WriteBatch batch = _db.batch(); // Inisialisasi batch

      // Asumsi sheet pertama yang digunakan
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows == 0) continue;

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.every(
            (cell) =>
                cell == null ||
                // ignore: invalid_null_aware_operator
                cell?.value == null ||
                cell.value.toString().trim().isEmpty,
          )) {
            continue;
          }

          try {
            String nama = row[1]?.value?.toString().trim() ?? '';
            String rumah = row[2]?.value?.toString().trim() ?? '';
            String hp = row[3]?.value?.toString().trim() ?? '';
            String status = row[4]?.value?.toString().trim() ?? '';
            String roleString = row[5]?.value?.toString().trim() ?? 'warga';
            String tanggalBergabungString =
                row[6]?.value?.toString().trim() ?? '';

            // --- Validasi Data ---
            if (nama.isEmpty || rumah.isEmpty) {
              failedRows.add('Baris ${i + 1}: Nama atau No. Rumah kosong.');
              continue;
            }
            if (hp.isNotEmpty && !RegExp(r'^[0-9+() -]+$').hasMatch(hp)) {
              failedRows.add('Baris ${i + 1}: Format No. HP tidak valid.');
              continue;
            }

            // Konversi role string ke enum UserRole
            UserRole userRole;
            try {
              userRole = UserRole.values.firstWhere(
                (e) => e.toString().split('.').last == roleString.toLowerCase(),
                orElse: () => UserRole
                    .warga, // Default ke 'warga' jika role tidak dikenali
              );
            } catch (e) {
              failedRows.add(
                'Baris ${i + 1}: Role "$roleString" tidak valid, diatur sebagai "warga".',
              );
              userRole = UserRole.warga;
            }

            // Optional: Konversi tanggal jika formatnya konsisten
            // DateTime? tanggalBergabung;
            // if (tanggalBergabungString.isNotEmpty) {
            // try {
            // tanggalBergabung = DateTime.parse(tanggalBergabungString); // Sesuaikan format jika perlu
            // } catch (e) {
            // failedRows.add('Baris ${i + 1}: Format tanggal bergabung tidak valid.');
            // // Biarkan null atau default
            // }
            // }

            // Buat objek WargaModel
            WargaModel newWarga = WargaModel(
              id: '', // ID akan digenerate oleh Firestore
              nama: nama,
              rumah: rumah,
              hp: hp,
              status: status,
              role: userRole
                  .toString()
                  .split('.')
                  .last, // Simpan sebagai string
              tanggalBergabung:
                  tanggalBergabungString, // Simpan tanggal sebagai string
            );

            // Tambahkan operasi ke batch
            batch.set(_db.collection('warga').doc(), newWarga.toMap());
            importedCount++;
          } catch (e, st) {
            failedRows.add('Baris ${i + 1}: Error tidak terduga ($e).');
            debugPrint('Error processing row ${i + 1}: $e \n $st');
          }
        }
        break; // Proses hanya sheet pertama, hapus ini untuk proses semua sheet
      }

      await batch.commit(); // Eksekusi semua operasi batch

      String message = 'Berhasil mengimpor $importedCount data warga.';
      if (failedRows.isNotEmpty) {
        message += '\n${failedRows.length} baris gagal diimpor:';
        for (int i = 0; i < failedRows.length && i < 3; i++) {
          // Tampilkan max 3 error detail
          message += '\n- ${failedRows[i]}';
        }
        if (failedRows.length > 3)
          message += '\n...dan ${failedRows.length - 3} lainnya.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(
              seconds: 10,
            ), // Durasi lebih lama untuk error
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e, st) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor data dari Excel: $e')),
      );
      debugPrint('Import Excel Error (Main): $e \n $st');
    }
  }
}
