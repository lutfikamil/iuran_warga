import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/whatsapp_service.dart';
import 'add_warga_page.dart';
import 'detail_warga_page.dart';
import '../../services/export_import_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../models/warga_model.dart';
import 'generate_iuran_page.dart';
import 'warga_keluar_page.dart';
import '../../utils/bulan_util.dart';

class WargaPage extends StatefulWidget {
  const WargaPage({super.key});

  @override
  State<WargaPage> createState() => _WargaPageState();
}

class _WargaPageState extends State<WargaPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allWargaDocs = [];
  bool _isWarga = false;
  bool _isSendingTagihan = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = SessionService.getRole();
    setState(() {
      _isWarga = role == 'warga';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi untuk menampilkan menu export/import
  void _showExportImportMenu(
    BuildContext context,
    List<DocumentSnapshot> wargaData,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export Excel'),
                onTap: () async {
                  Navigator.pop(bc);
                  await ExportImportService.exportWargaToExcel(
                    context,
                    wargaData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export PDF'),
                onTap: () async {
                  Navigator.pop(bc);
                  await ExportImportService.exportWargaToPdf(
                    context,
                    wargaData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import Excel'),
                onTap: () async {
                  Navigator.pop(bc);
                  await ExportImportService.importWargaFromExcel(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi helper untuk membuat TableRow ---
  TableRow _buildWargaTableRow(
    List<Widget> cells, {
    Color? backgroundColor,
    TextStyle? textStyle,
    VoidCallback? onTap,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: backgroundColor),
      children: cells.map((cell) {
        return GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DefaultTextStyle(
              style: textStyle ?? const TextStyle(),
              child: cell,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Warga"),
        actions: [
          // Hanya admin/petugas yang bisa generate & export import
          if (!_isWarga) ...[
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: "Generate 1 Tahun",
              onPressed: () => GeneratePage.generateIuranSetahunDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Generate Iuran",
              onPressed: () => GeneratePage.generateIuranDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.file_copy),
              tooltip: "Export / Import",
              onPressed: () => _showExportImportMenu(context, _allWargaDocs),
            ),
            IconButton(
              icon: _isSendingTagihan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: "Kirim Tagihan Bulan Ini",
              onPressed: _isSendingTagihan ? null : _kirimTagihanBulanIni,
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Arsip Warga Keluar',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WargaKeluarPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddWargaPage()),
                );
              },
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama, rumah, HP, atau status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("warga")
            .orderBy("rumah")
            .snapshots(),
        builder: (context, wargaSnapshot) {
          if (wargaSnapshot.hasError) {
            return Center(child: Text('Error: ${wargaSnapshot.error}'));
          }

          if (!wargaSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          _allWargaDocs = wargaSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("iuran").snapshots(),
            builder: (context, iuranSnapshot) {
              if (iuranSnapshot.hasError) {
                return Center(child: Text('Error: ${iuranSnapshot.error}'));
              }

              if (!iuranSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final iuranDocs = iuranSnapshot.data!.docs;

              // FILTER
              List<DocumentSnapshot> filteredWargaDocs = _allWargaDocs.where((
                doc,
              ) {
                final data = doc.data() as Map<String, dynamic>;
                final nama = data["nama"]?.toLowerCase() ?? '';
                final rumah = data["rumah"]?.toLowerCase() ?? '';
                final hp = data["noHpPenghuni"]?.toLowerCase() ?? '';
                final status = data["status"]?.toLowerCase() ?? '';

                return nama.contains(_searchQuery) ||
                    rumah.contains(_searchQuery) ||
                    hp.contains(_searchQuery) ||
                    status.contains(_searchQuery);
              }).toList();

              if (filteredWargaDocs.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Tidak ada data warga.'
                        : 'Tidak ditemukan "$_searchQuery"',
                  ),
                );
              }

              return _buildTable(filteredWargaDocs, iuranDocs);
            },
          );
        },
      ),
    );
  }

  Widget _buildTable(
    List<DocumentSnapshot> wargaDocs,
    List<QueryDocumentSnapshot> iuranDocs,
  ) {
    final tunggakanMap = hitungTunggakanSemuaWarga(iuranDocs);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FixedColumnWidth(50),
            1: FixedColumnWidth(70),
            2: FixedColumnWidth(150),
            3: FixedColumnWidth(120),
            4: FixedColumnWidth(100),
            5: FixedColumnWidth(100),
          },
          children: [
            _buildHeader(),
            ...List.generate(wargaDocs.length, (index) {
              final wargaDoc = wargaDocs[index];
              final warga = WargaModel.fromMap(
                wargaDoc.id,
                wargaDoc.data() as Map<String, dynamic>,
              );

              final jumlahTunggakan = tunggakanMap[wargaDoc.id] ?? 0;

              final statusText = jumlahTunggakan == 0
                  ? "Lunas"
                  : "$jumlahTunggakan bln";

              final statusColor = jumlahTunggakan > 0
                  ? Colors.red
                  : Colors.green;

              return _buildWargaTableRow(
                [
                  Text("${index + 1}", textAlign: TextAlign.center),
                  Text(warga.rumah, textAlign: TextAlign.center),
                  Text(warga.nama),
                  Text(warga.noHpPenghuni),
                  Text(warga.status, textAlign: TextAlign.center),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                backgroundColor: index.isEven
                    ? Colors.grey.shade50
                    : Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailWargaPage(wargaId: wargaDoc.id),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  TableRow _buildHeader() {
    return _buildWargaTableRow(
      const [
        Text("No", textAlign: TextAlign.center),
        Text("Rumah", textAlign: TextAlign.center),
        Text("Nama", textAlign: TextAlign.center),
        Text("HP", textAlign: TextAlign.center),
        Text("Status", textAlign: TextAlign.center),
        Text("Tunggakan", textAlign: TextAlign.center),
      ],
      backgroundColor: Colors.blue.withAlpha(1),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Map<String, int> hitungTunggakanSemuaWarga(
    List<QueryDocumentSnapshot> iuranDocs,
  ) {
    final now = DateTime.now();
    final Map<String, int> result = {};

    for (var doc in iuranDocs) {
      final data = doc.data() as Map<String, dynamic>;

      final wargaId = data['wargaId'];
      if (wargaId == null) continue;

      final isTunggakan = BulanUtil.isTunggakan(
        bulan: data['bulan'],
        tahun: data['tahun'],
        now: now,
      );

      final isBelumLunas = data['status']?.toString().toLowerCase() != 'lunas';

      if (isTunggakan && isBelumLunas) {
        result[wargaId] = (result[wargaId] ?? 0) + 1;
      }
    }

    return result;
  }

  Future<bool> _verifikasiPasswordSebelumKirim() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;

    final isVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: !isVerifying,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verifyPassword() async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final identifier = SessionService.getIdentifier();
              if (identifier == null || identifier.isEmpty) {
                if (!mounted) return;
                Navigator.of(dialogContext).pop(false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sesi login tidak ditemukan. Silakan login ulang.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() => isVerifying = true);

              try {
                await AuthService().loginFlexible(
                  identifier,
                  passwordController.text.trim(),
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Password verifikasi salah.')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isVerifying = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Verifikasi Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan password akun Anda untuk mengirim tagihan WhatsApp.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password wajib diisi';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!isVerifying) {
                          verifyPassword();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isVerifying ? null : verifyPassword,
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verifikasi'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return isVerified ?? false;
  }

  int hitungTunggakanWarga(
    List<QueryDocumentSnapshot> iuranDocs,
    String wargaId,
  ) {
    final now = DateTime.now();
    int total = 0;

    for (var doc in iuranDocs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data['wargaId'] != wargaId) continue;

      final isTunggakan = BulanUtil.isTunggakan(
        bulan: data['bulan'],
        tahun: data['tahun'],
        now: now,
      );

      final isBelumLunas = data['status']?.toString().toLowerCase() != 'lunas';

      if (isTunggakan && isBelumLunas) {
        total++;
      }
    }

    return total;
  }

  Future<void> _kirimTagihanBulanIni() async {
    if (_isSendingTagihan) return;

    final isVerified = await _verifikasiPasswordSebelumKirim();
    if (!isVerified) return;

    setState(() {
      _isSendingTagihan = true;
    });

    try {
      final now = DateTime.now();

      final bulan = BulanUtil.toStringMonth(now.month);
      final tahun = now.year;

      final iuranSnapshot = await FirebaseFirestore.instance
          .collection("iuran")
          .where("bulan", isEqualTo: bulan)
          .where("tahun", isEqualTo: tahun)
          .where("status", isEqualTo: "belum") // 🔥 hanya yang belum bayar
          .get();

      if (iuranSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada tagihan yang perlu dikirim")),
        );
        return;
      }

      int success = 0;
      int failed = 0;

      for (final doc in iuranSnapshot.docs) {
        try {
          final data = doc.data();

          final wargaDoc = await FirebaseFirestore.instance
              .collection("warga")
              .doc(data["wargaId"])
              .get();

          if (!wargaDoc.exists) continue;

          final warga = wargaDoc.data()!;
          final nama = warga["nama"] ?? '-';
          final hp = warga["noHpPenghuni"] ?? '';

          if (hp.toString().isEmpty) continue;

          await WhatsappService.sendMessage(
            phone: hp,
            message:
                '''
Halo Bapak/Ibu $nama 👋

Tagihan Iuran Anda saat ini:
Bulan: $bulan $tahun
Jumlah: Rp ${data["jumlah"]}

Mohon segera melakukan pembayaran untuk kelancaran kegiatan perumahan kita bersama.
Jika ada kendala anda bisa menghubungi kami di grup atau dm langsung.
Terimakasih $nama
''',
          );

          success++;

          /// 🔥 optional delay biar gak dianggap spam
          await Future.delayed(const Duration(milliseconds: 10000));
        } catch (e) {
          failed++;
          debugPrint("Gagal kirim WA: $e");
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("WA terkirim: $success\nGagal: $failed"),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error kirim WA: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTagihan = false;
        });
      }
    }
  }
}
