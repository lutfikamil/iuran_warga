import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/log_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import 'sekretaris_export.dart';

class SekretarisDataPage extends StatefulWidget {
  const SekretarisDataPage({super.key});

  @override
  State<SekretarisDataPage> createState() => _SekretarisDataPageState();
}

class _SekretarisDataPageState extends State<SekretarisDataPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
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

  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs;

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();

    super.dispose();
  }

  Future<void> _showEditDialog({
    String? docId,
    Map<String, dynamic>? initialData,
  }) async {
    if (!_canEdit) return;

    final isEditing = docId != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        final controllers = {
          for (final key in _dataHeaders)
            key: TextEditingController(
              text: (initialData?[key] ?? '').toString(),
            ),
        };

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
                'status': controllers['status']!.text
                    .trim(), // <-- nilai dari dropdown
                'dihuniOleh': controllers['dihuniOleh']!.text.trim(),
                'noHpPenghuni': controllers['noHpPenghuni']!.text.trim(),
                'noKtp': controllers['noKtp']!.text.trim(),
                'noKk': controllers['noKk']!.text.trim(),
                'keterangan': controllers['keterangan']!.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                if (isEditing) {
                  await _firestore.collection('data_sekretaris').doc(docId).set(
                    {...data, 'no': FieldValue.delete()},
                    SetOptions(merge: true),
                  );
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

                if (dialogContext.mounted)
                  Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan data: $e')),
                  );
                  setDialogState(() => isSaving = false);
                }
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
                      children: _dataHeaders.map((key) {
                        if (key == 'status') {
                          // ---- DROPDOWN UNTUK STATUS ----
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              value: controllers['status']!.text.isEmpty
                                  ? null
                                  : controllers['status']!.text,
                              items: ['Dihuni', 'Sewa', 'Kosong']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  controllers['status']!.text = value;
                                }
                              },
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Status wajib dipilih'
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          );
                        }

                        // field lainnya tetap TextFormField
                        return _buildField(
                          label: _labelFor(key),
                          controller: controllers[key]!,
                          keyboardType: key.contains('no')
                              ? TextInputType.number
                              : TextInputType.text,
                          validator: key == 'rumah'
                              ? (v) => v == null || v.trim().isEmpty
                                    ? 'Rumah wajib diisi'
                                    : null
                              : null,
                          maxLines: key == 'keterangan' ? 3 : 1,
                        );
                      }).toList(),
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
  }

  String _labelFor(String key) {
    switch (key) {
      case 'rumah':
        return 'Rumah';
      case 'pemilik':
        return 'Pemilik';
      case 'noHpPemilik':
        return 'No Hp';
      case 'status':
        return 'Status';
      case 'dihuniOleh':
        return 'Dihuni Oleh';
      case 'noHpPenghuni':
        return 'No. Hp Penghuni';
      case 'noKtp':
        return 'No KTP';
      case 'noKk':
        return 'No KK';
      case 'keterangan':
        return 'Keterangan';
      default:
        return key;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sekretaris'),
        actions: [
          if (_canEdit) ...[
            IconButton(
              tooltip: 'Export Excel',
              onPressed: () => SekretarisExport.exportExcel(_filteredDocs),
              icon: const Icon(Icons.file_download),
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: () => SekretarisExport.exportPdf(_filteredDocs),
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
              (v) => v.toString().toLowerCase().contains(_searchQuery),
            );
          }).toList();

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

          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: IntrinsicWidth(
                          child: Table(
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                            ),
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
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                children: const [
                                  Text('No', textAlign: TextAlign.center),
                                  Text('Rumah', textAlign: TextAlign.center),
                                  Text('Pemilik', textAlign: TextAlign.center),
                                  Text('No hp', textAlign: TextAlign.center),
                                  Text('Status', textAlign: TextAlign.center),
                                  Text(
                                    'Dihuni oleh',
                                    textAlign: TextAlign.center,
                                  ),
                                  Text('No. Hp', textAlign: TextAlign.center),
                                  Text('No KTP', textAlign: TextAlign.center),
                                  Text('No KK', textAlign: TextAlign.center),
                                  Text(
                                    'Keterangan',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              ...List.generate(docs.length, (index) {
                                final doc = docs[index];
                                final data = doc.data();
                                return _buildRow(
                                  color: index.isEven
                                      ? Colors.grey.shade50
                                      : Colors.white,
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
                                    Text(
                                      data['noHpPemilik']?.toString() ?? '-',
                                    ),
                                    Text(data['status']?.toString() ?? '-'),
                                    Text(data['dihuniOleh']?.toString() ?? '-'),
                                    Text(
                                      data['noHpPenghuni']?.toString() ?? '-',
                                    ),
                                    Text(data['noKtp']?.toString() ?? '-'),
                                    Text(data['noKk']?.toString() ?? '-'),
                                    Text(data['keterangan']?.toString() ?? '-'),
                                  ],
                                );
                              }),
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
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Tambah Data'),
            )
          : null,
    );
  }
}
