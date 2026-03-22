import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/log_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class SekretarisDataPage extends StatefulWidget {
  const SekretarisDataPage({super.key});

  @override
  State<SekretarisDataPage> createState() => _SekretarisDataPageState();
}

class _SekretarisDataPageState extends State<SekretarisDataPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  bool get _canEdit {
    final role = AuthService.normalizeRole(SessionService.getRole());
    return role == 'admin' || role == 'ketua' || role == 'sekretaris';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog({
    String? docId,
    Map<String, dynamic>? initialData,
  }) async {
    if (!_canEdit) return;

    final formKey = GlobalKey<FormState>();
    final controllers = {
      for (final key in _dataHeaders)
        key: TextEditingController(text: (initialData?[key] ?? '').toString()),
    };

    try {
      final isEditing = docId != null;
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> save() async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                setDialogState(() => isSaving = true);

                final rumah = controllers['rumah']!.text.trim().toUpperCase();
                final data = <String, dynamic>{
                  'rumah': rumah,
                  'pemilik': controllers['pemilik']!.text.trim(),
                  'noHpPemilik': controllers['noHpPemilik']!.text.trim(),
                  'status': controllers['status']!.text.trim(),
                  'dihuniOleh': controllers['dihuniOleh']!.text.trim(),
                  'noHpPenghuni': controllers['noHpPenghuni']!.text.trim(),
                  'noKtp': controllers['noKtp']!.text.trim(),
                  'noKk': controllers['noKk']!.text.trim(),
                  'keterangan': controllers['keterangan']!.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  if (isEditing) {
                    await _firestore
                        .collection('data_sekretaris')
                        .doc(docId)
                        .set({
                          ...data,
                          'no': FieldValue.delete(),
                        }, SetOptions(merge: true));
                  } else {
                    data['createdAt'] = FieldValue.serverTimestamp();
                    await _firestore.collection('data_sekretaris').add(data);
                  }

                  await LogService().logEvent(
                    action: isEditing
                        ? 'update_data_sekretaris'
                        : 'tambah_data_sekretaris',
                    target: 'data_sekretaris',
                    detail:
                        '${isEditing ? 'Update' : 'Tambah'} data sekretaris rumah $rumah',
                  );

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan data: $e')),
                  );
                  setDialogState(() => isSaving = false);
                }
              }

              return AlertDialog(
                title: Text(
                  isEditing ? 'Edit Data Sekretaris' : 'Tambah Data Sekretaris',
                ),
                content: SizedBox(
                  width: 700,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildField(
                            label: 'Rumah',
                            controller: controllers['rumah']!,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Rumah wajib diisi'
                                : null,
                          ),
                          _buildField(
                            label: 'Pemilik',
                            controller: controllers['pemilik']!,
                          ),
                          _buildField(
                            label: 'No Hp',
                            controller: controllers['noHpPemilik']!,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildField(
                            label: 'Status',
                            controller: controllers['status']!,
                          ),
                          _buildField(
                            label: 'Dihuni Oleh',
                            controller: controllers['dihuniOleh']!,
                          ),
                          _buildField(
                            label: 'No. Hp Penghuni',
                            controller: controllers['noHpPenghuni']!,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildField(
                            label: 'No KTP',
                            controller: controllers['noKtp']!,
                            keyboardType: TextInputType.number,
                          ),
                          _buildField(
                            label: 'No KK',
                            controller: controllers['noKk']!,
                            keyboardType: TextInputType.number,
                          ),
                          _buildField(
                            label: 'Keterangan',
                            controller: controllers['keterangan']!,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
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

      if ((result ?? false) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Data sekretaris berhasil diperbarui.'
                  : 'Data sekretaris berhasil ditambahkan.',
            ),
          ),
        );
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  TableRow _buildRow({
    required List<Widget> children,
    Color? color,
    VoidCallback? onTap,
    TextStyle? textStyle,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: color),
      children: children
          .map(
            (child) => InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DefaultTextStyle(
                  style: textStyle ?? const TextStyle(color: Colors.black87),
                  child: child,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// EXPORT EXCEL
  Future<void> _exportExcel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['DataSekretaris'];

    // header
    sheet.appendRow([
      TextCellValue('no'),
      ..._dataHeaders.map((header) => TextCellValue(header)),
    ]);

    // data
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final d = doc.data();
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        ..._dataHeaders.map(
          (header) => TextCellValue(d[header]?.toString() ?? ''),
        ),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/data_sekretaris.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Export Data Sekretaris');
  }

  /// IMPORT EXCEL
  //  Future<void> _importExcel() async {
  //    if (!_canEdit) return;
  //
  //    final result = await FilePicker.platform.pickFiles(
  //      type: FileType.custom,
  //      allowedExtensions: ['xlsx'],
  //    );
  //
  //    if (result == null || result.files.single.bytes == null) return;
  //
  //    final bytes = result.files.single.bytes!;
  //    final excel = Excel.decodeBytes(bytes);
  //    final sheet = excel.tables[excel.tables.keys.first];
  //
  //    if (sheet == null || sheet.rows.isEmpty) return;
  //
  //    final headerRow = sheet.rows.first
  //        .map((c) => c?.value?.toString().trim() ?? '')
  //        .toList();
  //    final colIndex = {
  //      for (var i = 0; i < headerRow.length; i++) headerRow[i]: i,
  //    };
  //
  //    if (!_headers.every((h) => colIndex.containsKey(h))) {
  //      if (mounted) {
  //        ScaffoldMessenger.of(context).showSnackBar(
  //          const SnackBar(
  //            content: Text('Format Excel tidak cocok dengan header'),
  //          ),
  //        );
  //      }
  //      return;
  //    }
  //
  //    final batch = _firestore.batch();
  //    for (var i = 1; i < sheet.rows.length; i++) {
  //      final row = sheet.rows[i];
  //      if (row.isEmpty) continue;
  //
  //      final data = <String, dynamic>{
  //        for (final h in _headers) h: row[colIndex[h]!]?.value?.toString() ?? '',
  //        'createdAt': FieldValue.serverTimestamp(),
  //        'updatedAt': FieldValue.serverTimestamp(),
  //      };
  //
  //      final docRef = _firestore.collection('data_sekretaris').doc();
  //      batch.set(docRef, data);
  //    }
  //
  //    await batch.commit();
  //
  //    await LogService().logEvent(
  //      action: 'import_data_sekretaris',
  //      target: 'data_sekretaris',
  //      detail: 'Import ${sheet.rows.length - 1} baris dari Excel',
  //    );
  //    if (mounted) {
  //      ScaffoldMessenger.of(
  //        context,
  //      ).showSnackBar(const SnackBar(content: Text('Import Excel berhasil')));
  //    }
  //  }

  /// EXPORT PDF
  Future<void> _exportPdf(
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
              final doc = entry.value;
              final d = doc.data();
              return [
                '${index + 1}',
                ..._dataHeaders.map((header) => d[header]?.toString() ?? ''),
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

  //  /// IMPORT EXCEL
  //  Future<void> importExcel() async {
  //    if (!_canEdit) return;
  //
  //    final result = await FilePicker.platform.pickFiles(
  //      type: FileType.custom,
  //      allowedExtensions: ['xlsx'],
  //    );
  //
  //    if (result == null || result.files.single.bytes == null) return;
  //
  //    final bytes = result.files.single.bytes!;
  //    final excel = Excel.decodeBytes(bytes);
  //    final sheet = excel.tables[excel.tables.keys.first];
  //
  //    if (sheet == null || sheet.rows.isEmpty) return;
  //
  //    final headerRow = sheet.rows.first
  //        .map((c) => c?.value?.toString().trim())
  //        .toList();
  //    final colIndex = {
  //      for (var i = 0; i < headerRow.length; i++) headerRow[i] ?? '': i,
  //    };
  //
  //    // pastikan semua header ada
  //    if (!_headers.every((h) => colIndex.containsKey(h))) {
  //      if (mounted) {
  //        ScaffoldMessenger.of(context).showSnackBar(
  //          const SnackBar(
  //            content: Text('Format Excel tidak cocok dengan header'),
  //          ),
  //        );
  //      }
  //      return;
  //    }
  //
  //    final batch = _firestore.batch();
  //    for (var i = 1; i < sheet.rows.length; i++) {
  //      final row = sheet.rows[i];
  //      if (row.isEmpty) continue;
  //
  //      final data = <String, dynamic>{
  //        for (final h in _headers) h: row[colIndex[h]!]?.value?.toString() ?? '',
  //        'createdAt': FieldValue.serverTimestamp(),
  //        'updatedAt': FieldValue.serverTimestamp(),
  //      };
  //
  //      final docRef = _firestore.collection('data_sekretaris').doc();
  //      batch.set(docRef, data);
  //    }
  //
  //    await batch.commit();
  //
  //    await LogService().logEvent(
  //      action: 'import_data_sekretaris',
  //      target: 'data_sekretaris',
  //      detail: 'Import ${sheet.rows.length - 1} baris dari Excel',
  //    );
  //    if (mounted) {
  //      ScaffoldMessenger.of(
  //        context,
  //      ).showSnackBar(const SnackBar(content: Text('Import Excel berhasil')));
  //    }
  //  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sekretaris'),
        actions: [
          if (_canEdit) ...[
            //  IconButton(
            //    tooltip: 'Import Excel',
            //    onPressed: _importExcel,
            //    icon: const Icon(Icons.upload_file),
            //  ),
            IconButton(
              tooltip: 'Export Excel',
              onPressed: () {
                final docs = context
                    .findAncestorStateOfType<_SekretarisDataPageState>()!
                    ._filteredDocs;
                _exportExcel(docs);
              },
              icon: const Icon(Icons.file_download),
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: () {
                final docs = context
                    .findAncestorStateOfType<_SekretarisDataPageState>()!
                    ._filteredDocs;
                _exportPdf(docs);
              },
              icon: const Icon(Icons.picture_as_pdf),
            ),
            IconButton(
              tooltip: 'Tambah data',
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.add),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari rumah, pemilik, penghuni, status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('data_sekretaris')
            .orderBy('rumah')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            if (_searchQuery.isEmpty) return true;

            final values = [
              data['rumah'],
              data['pemilik'],
              data['noHpPemilik'],
              data['status'],
              data['dihuniOleh'],
              data['noHpPenghuni'],
              data['noKtp'],
              data['noKk'],
              data['keterangan'],
            ];

            return values.any(
              (value) => value.toString().toLowerCase().contains(_searchQuery),
            );
          }).toList();

          // simpan untuk export
          _filteredDocs = docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'Belum ada data sekretaris.'
                    : 'Data dengan kata kunci "$_searchQuery" tidak ditemukan.',
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FixedColumnWidth(60),
                  1: FixedColumnWidth(90),
                  2: FixedColumnWidth(180),
                  3: FixedColumnWidth(140),
                  4: FixedColumnWidth(100),
                  5: FixedColumnWidth(180),
                  6: FixedColumnWidth(140),
                  7: FixedColumnWidth(180),
                  8: FixedColumnWidth(180),
                  9: FixedColumnWidth(220),
                },
                children: [
                  _buildRow(
                    color: Colors.blue.withValues(alpha: 0.12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    children: const [
                      Text('No', textAlign: TextAlign.center),
                      Text('Rumah', textAlign: TextAlign.center),
                      Text('Pemilik', textAlign: TextAlign.center),
                      Text('No hp', textAlign: TextAlign.center),
                      Text('Status', textAlign: TextAlign.center),
                      Text('Dihuni oleh', textAlign: TextAlign.center),
                      Text('No. Hp', textAlign: TextAlign.center),
                      Text('No KTP', textAlign: TextAlign.center),
                      Text('No KK', textAlign: TextAlign.center),
                      Text('Keterangan', textAlign: TextAlign.center),
                    ],
                  ),
                  ...List.generate(docs.length, (index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _buildRow(
                      color: index.isEven ? Colors.grey.shade50 : Colors.white,
                      onTap: _canEdit
                          ? () => _showEditDialog(
                              docId: doc.id,
                              initialData: data,
                            )
                          : null,
                      children: [
                        Text('${index + 1}'),
                        Text(data['rumah']?.toString() ?? '-'),
                        Text(data['pemilik']?.toString() ?? '-'),
                        Text(data['noHpPemilik']?.toString() ?? '-'),
                        Text(data['status']?.toString() ?? '-'),
                        Text(data['dihuniOleh']?.toString() ?? '-'),
                        Text(data['noHpPenghuni']?.toString() ?? '-'),
                        Text(data['noKtp']?.toString() ?? '-'),
                        Text(data['noKk']?.toString() ?? '-'),
                        Text(data['keterangan']?.toString() ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Tambah Data'),
            )
          : null,
    );
  }

  // helper untuk export
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs;
}
