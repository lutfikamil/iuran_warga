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
import 'whatsapp_service.dart';

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
      excel.delete('Sheet1');
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
  // ==============================================
  //           IMPORT WARGA DARI EXCEL (REFACTOR)
  // ==============================================
  static Future<void> importWargaFromExcel(BuildContext context) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Memulai import data...')));

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pemilihan file dibatalkan')),
        );
        return;
      }

      final bytes = result.files.single.bytes!;
      final excel = Excel.decodeBytes(bytes);

      final existingSnapshot = await _db.collection('warga').get();

      /// 🔥 Map rumah untuk deteksi duplikat
      final Map<String, DocumentReference> rumahMap = {
        for (var doc in existingSnapshot.docs)
          (doc.data()['rumah'] ?? '').toString().toUpperCase(): doc.reference,
      };

      final batch = _db.batch();

      int successCount = 0;
      final List<String> failedRows = [];

      /// 🔥 simpan data user setelah commit
      final List<Map<String, dynamic>> usersToCreate = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.row(i);

          if (_isRowEmpty(row)) continue;

          try {
            final nama = _safeString(row, 1);
            final rumahRaw = _safeString(row, 2);
            final hp = _safeString(row, 3);
            final status = _safeString(row, 4);
            final role = _safeString(row, 5).toLowerCase();
            final tanggal = _safeString(row, 6);

            if (nama.isEmpty || rumahRaw.isEmpty) {
              failedRows.add('Baris ${i + 1}: Nama/Rumah kosong');
              continue;
            }

            if (hp.isNotEmpty && !_isValidHp(hp)) {
              failedRows.add('Baris ${i + 1}: HP tidak valid');
              continue;
            }

            /// 🔥 NORMALISASI RUMAH (SAMA DENGAN AddWargaPage)
            final rumahData = _generateRumahData(rumahRaw);
            final rumah = rumahData['rumah'];
            final blok = rumahData['blok'];
            final nomor = rumahData['nomor'];

            final wargaData = {
              'nama': nama,
              'rumah': rumah,
              'blok': blok,
              'nomor': nomor,
              'hp': hp,
              'status': status,
              'role': role.isEmpty ? 'warga' : role,
              'tanggalBergabung': tanggal,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            DocumentReference ref;

            if (rumahMap.containsKey(rumah)) {
              /// UPDATE
              ref = rumahMap[rumah]!;
              batch.update(ref, wargaData);
            } else {
              /// CREATE
              ref = _db.collection('warga').doc();
              batch.set(ref, {
                ...wargaData,
                'createdAt': FieldValue.serverTimestamp(),
              });

              rumahMap[rumah] = ref;
            }

            /// 🔥 simpan untuk create login
            usersToCreate.add({
              'wargaId': ref.id,
              'nama': nama,
              'rumah': rumah,
              'hp': hp,
              'role': wargaData['role'],
            });

            successCount++;
          } catch (e) {
            failedRows.add('Baris ${i + 1}: Error $e');
          }
        }

        break;
      }

      /// ✅ Commit warga dulu
      await batch.commit();

      /// =========================================
      /// 🔥 CREATE / UPDATE USER LOGIN
      /// =========================================
      int userSuccess = 0;

      const defaultPassword = '123456';

      for (final user in usersToCreate) {
        try {
          final nama = user['nama'];
          final hp = user['hp'];
          final rumah = user['rumah'];

          final identifier = _resolveIdentifier(hp, rumah);
          final email = '$identifier@mulialand.com';

          await upsertUserLogin(
            wargaId: user['wargaId'],
            nama: nama,
            rumah: rumah,
            hp: hp,
            role: user['role'],
            identifier: identifier,
            newRawPassword: defaultPassword,
          );

          /// 🔥 AUTO KIRIM WA
          if (hp != null && hp.toString().isNotEmpty) {
            await WhatsappService.sendMessage(
              phone: hp,
              message:
                  '''
Halo Bapak/Ibu $nama

Akun Anda telah dibuat.
Untuk mengetahui Informasi pembayaran iuran Anda dan
Keadaan keuangan di Perumahan kita tercinta ini.

  Login:
Email: $email
Password: $defaultPassword

Silakan login dan segera ganti password.
Jika ada pertanyaan jangan sungkan untuk menghubungi kami baik di Group atau DM langsung.

Terima kasih
Pengurus Perumahan Mulia Land Patria. 
''',
            );

            /// 🔥 biar gak dianggap spam
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        } catch (e) {
          debugPrint('Error: $e');
        }
      }

      /// =========================================
      /// 🔔 NOTIFIKASI
      /// =========================================
      String message =
          'Import selesai:\n'
          '- Warga: $successCount\n'
          '- User login: $userSuccess';

      if (failedRows.isNotEmpty) {
        message += '\nGagal: ${failedRows.length} baris';
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal import: $e')));
    }
  }

  static bool _isRowEmpty(List<Data?> row) {
    return row.every(
      (cell) =>
          cell == null ||
          cell.value == null ||
          cell.value.toString().trim().isEmpty,
    );
  }

  static String _safeString(List<Data?> row, int index) {
    if (index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  static bool _isValidHp(String hp) {
    return RegExp(r'^[0-9+() -]+$').hasMatch(hp);
  }

  static String _resolveIdentifier(String hp, String rumah) {
    return hp.isNotEmpty ? hp : rumah;
  }

  static Map<String, dynamic> _generateRumahData(String rumah) {
    final upper = rumah.toUpperCase();

    final huruf = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    final angkaStr = upper.replaceAll(RegExp(r'[^0-9]'), '');
    final angka = int.tryParse(angkaStr) ?? 0;
    final angkaFormatted = angka.toString().padLeft(2, '0');

    return {'rumah': '$huruf$angkaFormatted', 'blok': huruf, 'nomor': angka};
  }
}
