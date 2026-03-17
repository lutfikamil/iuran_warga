import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/iuran_service.dart';

class PembayaranPage extends StatefulWidget {
  const PembayaranPage({super.key});

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  final ScrollController _scrollController = ScrollController();

  static const EdgeInsets _defaultPadding = EdgeInsets.all(8.0);
  static const double _tableCellWidthNo = 50.0;
  static const double _tableCellWidthRumah = 80.0;
  static const double _tableCellWidthNama = 150.0;
  static const double _tableCellWidthBulan = 90.0;
  static const double _tableCellWidthJumlah = 120.0;
  static const double _tableCellWidthStatus = 80.0;
  static const double _tableCellWidthAksi = 120.0;

  // Filter default: bulan & tahun sekarang
  String _selectedBulan = '';
  int _selectedTahun = DateTime.now().year;
  final List<String> _bulanList = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  // Pagination
  final List<DocumentSnapshot> _iuranDocs = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;

  Map<String, Map<String, dynamic>> _wargaMap = {};

  @override
  void initState() {
    super.initState();
    _selectedBulan = _bulanList[DateTime.now().month - 1];
    _loadWarga();
    _loadIuran(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 50 &&
          !_isLoading &&
          _hasMore) {
        _loadIuran();
      }
    });
  }

  Future<void> _loadWarga() async {
    final snap = await FirebaseFirestore.instance.collection("warga").get();
    _wargaMap = {for (var d in snap.docs) d.id: d.data()};
    setState(() {});
  }

  Future<void> _loadIuran({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (reset) {
      _iuranDocs.clear();
      _lastDoc = null;
      _hasMore = true;
    }

    Query query = FirebaseFirestore.instance
        .collection("iuran")
        .where("bulan", isEqualTo: _selectedBulan)
        .where("tahun", isEqualTo: _selectedTahun)
        .orderBy(
          "wargaId",
        ) // pastikan ada index composite (bulan, tahun, wargaId)
        .limit(20);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snap = await query.get();

    if (snap.docs.isEmpty) {
      _hasMore = false;
    } else {
      _iuranDocs.addAll(snap.docs);
      _lastDoc = snap.docs.last;
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TableRow _buildHeaderRow() {
    return const TableRow(
      decoration: BoxDecoration(color: Colors.blue),
      children: [
        Padding(
          padding: _defaultPadding,
          child: Text("No", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Rumah", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Nama", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Bulan", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Jumlah", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Status", style: TextStyle(color: Colors.white)),
        ),
        Padding(
          padding: _defaultPadding,
          child: Text("Aksi", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _updateIuranMonth(String iuranId, String bulanBaru) async {
    await FirebaseFirestore.instance.collection('iuran').doc(iuranId).update({
      'bulan': bulanBaru,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bulan iuran diubah ke $bulanBaru.')));
    _loadIuran(reset: true);
  }

  TableRow _buildDataRow(
    int index,
    Map<String, dynamic> iuranData,
    Map<String, dynamic> wargaData,
    String iuranId,
  ) {
    final status = iuranData["status"];
    final namaWarga = wargaData["nama"] ?? '-';
    final bulanIuran = (iuranData["bulan"] ?? '-').toString();
    final selectedBulan = _bulanList.contains(bulanIuran) ? bulanIuran : null;
    final jumlahIuran = iuranData["jumlah"] ?? '0';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.withValues(alpha: 0.05) : null,
      ),
      children: [
        Padding(padding: _defaultPadding, child: Text((index + 1).toString())),
        Padding(
          padding: _defaultPadding,
          child: Text(wargaData["rumah"] ?? '-'),
        ),
        Padding(padding: _defaultPadding, child: Text(namaWarga)),
        Padding(
          padding: _defaultPadding,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedBulan,
              hint: const Text('Pilih bulan'),
              items: _bulanList
                  .map(
                    (bulan) => DropdownMenuItem<String>(
                      value: bulan,
                      child: Text(bulan),
                    ),
                  )
                  .toList(),
              onChanged: (bulanBaru) async {
                if (bulanBaru == null || bulanBaru == bulanIuran) return;
                await _updateIuranMonth(iuranId, bulanBaru);
              },
            ),
          ),
        ),
        Padding(padding: _defaultPadding, child: Text("Rp $jumlahIuran")),
        Padding(
          padding: _defaultPadding,
          child: status == "lunas"
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.close, color: Colors.red),
        ),
        Padding(
          padding: _defaultPadding,
          child: status == "belum"
              ? ElevatedButton(
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Konfirmasi Pembayaran'),
                        content: Text(
                          'Anda yakin ingin menandai iuran bulan "$bulanIuran" untuk "$namaWarga" sebesar Rp $jumlahIuran sebagai lunas?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Ya, Bayar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await IuranService().bayar(iuranId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil!')),
                        );
                      }
                    }
                  },
                  child: const Text("Bayar"),
                )
              : const Text("Lunas"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pembayaran Iuran"),
        actions: [
          // Filter bulan & tahun
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<int>(
              value: _selectedTahun,
              underline: const SizedBox(),
              items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.toString())),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedTahun = v!);
                _loadIuran(reset: true);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: _selectedBulan,
              underline: const SizedBox(),
              items: _bulanList
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedBulan = v!);
                _loadIuran(reset: true);
              },
            ),
          ),
        ],
      ),
      body: _wargaMap.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header tetap
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FixedColumnWidth(_tableCellWidthNo),
                      1: FixedColumnWidth(_tableCellWidthRumah),
                      2: FixedColumnWidth(_tableCellWidthNama),
                      3: FixedColumnWidth(_tableCellWidthBulan),
                      4: FixedColumnWidth(_tableCellWidthJumlah),
                      5: FixedColumnWidth(_tableCellWidthStatus),
                      6: FixedColumnWidth(_tableCellWidthAksi),
                    },
                    children: [_buildHeaderRow()],
                  ),
                ),
                // Body dengan scroll + pagination
                Expanded(
                  child: _iuranDocs.isEmpty && !_isLoading
                      ? Center(
                          child: Text(
                            'Tidak ada data iuran untuk $_selectedBulan $_selectedTahun.',
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _iuranDocs.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _iuranDocs.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final iuranDoc = _iuranDocs[index];
                              final iuranData =
                                  iuranDoc.data() as Map<String, dynamic>;
                              final iuranId = iuranDoc.id;
                              final wargaData = _wargaMap[iuranData["wargaId"]];

                              if (wargaData == null) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Table(
                                    border: TableBorder.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    columnWidths: const {
                                      0: FixedColumnWidth(_tableCellWidthNo),
                                      1: FixedColumnWidth(_tableCellWidthRumah),
                                      2: FixedColumnWidth(_tableCellWidthNama),
                                      3: FixedColumnWidth(_tableCellWidthBulan),
                                      4: FixedColumnWidth(_tableCellWidthJumlah),
                                      5: FixedColumnWidth(_tableCellWidthStatus),
                                      6: FixedColumnWidth(_tableCellWidthAksi),
                                    },
                                    children: [
                                      TableRow(
                                        children: [
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(
                                              'Data Warga Tidak Ditemukan',
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                          const Padding(
                                            padding: _defaultPadding,
                                            child: Text(''),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Table(
                                  border: TableBorder.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(_tableCellWidthNo),
                                    1: FixedColumnWidth(_tableCellWidthRumah),
                                    2: FixedColumnWidth(_tableCellWidthNama),
                                    3: FixedColumnWidth(_tableCellWidthBulan),
                                    4: FixedColumnWidth(_tableCellWidthJumlah),
                                    5: FixedColumnWidth(_tableCellWidthStatus),
                                    6: FixedColumnWidth(_tableCellWidthAksi),
                                  },
                                  children: [
                                    _buildDataRow(
                                      index,
                                      iuranData,
                                      wargaData,
                                      iuranId,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
