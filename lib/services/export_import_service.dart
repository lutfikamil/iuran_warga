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
import 'users_service.dart';
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

  // ==============================================
  //        DOWNLOAD / EXPORT WARGA KE EXCEL
  // ==============================================
  static Future<void> exportWargaToExcel(
    BuildContext context,
    List<DocumentSnapshot> wargaDocs,
  ) async {
    try {
      if (wargaDocs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data warga untuk diekspor.')),
        );
        return;
      }

      final excel = Excel.createExcel();

      // 🔥 hapus default sheet dengan aman
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['Data Warga'];

      // Header
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama'),
        TextCellValue('Rumah'),
        TextCellValue('HP'),
        TextCellValue('Status'),
        TextCellValue('Role'),
        TextCellValue('Tanggal Bergabung'),
      ]);

      // Data
      for (int i = 0; i < wargaDocs.length; i++) {
        final data = wargaDocs[i].data() as Map<String, dynamic>;

        sheet.appendRow([
          TextCellValue((i + 1).toString()),
          TextCellValue(data["nama"] ?? '-'),
          TextCellValue(data["rumah"] ?? '-'),
          TextCellValue(data["hp"] ?? '-'),
          TextCellValue(data["status"] ?? '-'),
          TextCellValue(data["role"] ?? 'warga'),
          TextCellValue(data["tanggalBergabung"] ?? '-'),
        ]);
      }

      final excelBytes = excel.encode();
      if (excelBytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengkodekan Excel')),
        );
        return;
      }

      final fileName =
          'data_warga_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        _downloadFileWeb(
          excelBytes,
          fileName,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Excel berhasil diunduh')));
      } else {
        File? file;

        try {
          final tempDir = await getTemporaryDirectory();
          file = File('${tempDir.path}/$fileName');

          await file.writeAsBytes(excelBytes);

          await Share.shareXFiles([XFile(file.path)], text: 'Data Warga');

          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Excel siap dibagikan')));
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal export Excel: $e')));
        } finally {
          if (file != null && await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e, st) {
      debugPrint('Export Excel Error: $e \n $st');

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    }
  }

  // ==============================================
  //        DOWNLOAD / EXPORT WARGA KE PDF
  // ==============================================
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
        wargaData["role"] ?? 'warga',
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
            pw.TableHelper.fromTextArray(
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
        'data_warga_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';

    if (kIsWeb) {
      // --- Logika untuk Web ---
      _downloadFileWeb(pdfBytes, fileName, 'application/pdf');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan PDF telah diunduh!')),
      );
    } else {
      File? file;

      try {
        final tempDir = await getTemporaryDirectory();
        file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Data Warga');

        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF siap dibagikan')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal export PDF: $e')));
      } finally {
        if (file != null && await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  // ==============================================
  //           IMPORT WARGA DARI EXCEL
  // ==============================================
  static Future<void> importWargaFromExcel(BuildContext context) async {
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
        withData: true, // 🔥 penting untuk web
      );

      if (result == null || result.files.single.bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemilihan file dibatalkan.')),
        );
        return;
      }
      final existingWargaSnapshot = await _db.collection('warga').get();

      Map<String, DocumentReference> rumahMap = {};

      for (var doc in existingWargaSnapshot.docs) {
        final data = doc.data();
        final rumah = (data['rumah'] ?? '').toString().toUpperCase();

        if (rumah.isNotEmpty) {
          rumahMap[rumah] = doc.reference;
        }
      }
      // ✅ Ambil bytes (support semua platform)
      final bytes = result.files.single.bytes!;
      final excel = Excel.decodeBytes(bytes);

      int importedCount = 0;
      List<String> failedRows = [];

      WriteBatch batch = _db.batch();

      // 🔥 Simpan data untuk create user setelah batch commit
      List<Map<String, dynamic>> importedUsers = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows == 0) continue;

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);

          // Skip baris kosong
          if (row.every(
            (cell) =>
                cell == null ||
                cell.value == null ||
                cell.value.toString().trim().isEmpty,
          )) {
            continue;
          }

          try {
            String nama = row[1]?.value?.toString().trim() ?? '';
            String rumah = row[2]?.value?.toString().trim() ?? '';
            String hp = row[3]?.value?.toString().trim() ?? '';
            String status = row[4]?.value?.toString().trim() ?? '';
            String roleString =
                row[5]?.value?.toString().trim().toLowerCase() ?? 'warga';
            String tanggalBergabung = row[6]?.value?.toString().trim() ?? '';

            // ✅ Validasi
            if (nama.isEmpty || rumah.isEmpty) {
              failedRows.add('Baris ${i + 1}: Nama atau Rumah kosong.');
              continue;
            }

            if (hp.isNotEmpty && !RegExp(r'^[0-9+() -]+$').hasMatch(hp)) {
              failedRows.add('Baris ${i + 1}: Format HP tidak valid.');
              continue;
            }

            // ✅ Role parsing
            UserRole userRole = UserRole.values.firstWhere(
              (e) => e.toString().split('.').last == roleString,
              orElse: () => UserRole.warga,
            );

            // 🔥 Buat doc ref dulu biar dapat ID
            final rumahUpper = rumah.toUpperCase();
            final wargaData = {
              'nama': nama,
              'rumah': rumahUpper,
              'hp': hp,
              'status': status,
              'role': userRole.toString().split('.').last,
              'tanggalBergabung': tanggalBergabung,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (rumahMap.containsKey(rumahUpper)) {
              // 🔥 UPDATE
              final existingRef = rumahMap[rumahUpper]!;

              batch.update(existingRef, wargaData);

              importedUsers.add({
                'wargaId': existingRef.id,
                'nama': nama,
                'rumah': rumahUpper,
                'hp': hp,
                'role': userRole.toString().split('.').last,
              });
            } else {
              // 🔥 CREATE
              final newRef = _db.collection('warga').doc();

              batch.set(newRef, {
                ...wargaData,
                'createdAt': FieldValue.serverTimestamp(),
              });

              rumahMap[rumahUpper] = newRef;

              importedUsers.add({
                'wargaId': newRef.id,
                'nama': nama,
                'rumah': rumahUpper,
                'hp': hp,
                'role': userRole.toString().split('.').last,
              });
            }

            importedCount++;
          } catch (e, st) {
            failedRows.add('Baris ${i + 1}: Error ($e)');
            debugPrint('Row error ${i + 1}: $e \n $st');
          }
        }
        break; // hanya sheet pertama
      }

      // ✅ Commit semua warga dulu
      await batch.commit();

      // =========================================
      // 🔥 CREATE USER LOGIN (SETELAH WARGA MASUK)
      // =========================================
      for (var user in importedUsers) {
        try {
          final identifier =
              (user['hp'] != null && user['hp'].toString().isNotEmpty)
              ? user['hp']
              : user['rumah'];

          await upsertUserLogin(
            wargaId: user['wargaId'],
            nama: user['nama'],
            rumah: user['rumah'],
            hp: user['hp'],
            role: user['role'],
            identifier: identifier,
            newRawPassword: '123456', // 🔥 default password
          );
        } catch (e) {
          debugPrint('User create error: $e');
        }
      }

      // =========================================
      // 🔔 NOTIFIKASI
      // =========================================
      String message = 'Berhasil mengimpor $importedCount warga.';

      if (failedRows.isNotEmpty) {
        message += '\n${failedRows.length} baris gagal:';
        for (int i = 0; i < failedRows.length && i < 3; i++) {
          message += '\n- ${failedRows[i]}';
        }
        if (failedRows.length > 3) {
          message += '\n...dan ${failedRows.length - 3} lainnya.';
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal import Excel: $e')));
      debugPrint('Import Excel Error: $e \n $st');
    }
  }
}
