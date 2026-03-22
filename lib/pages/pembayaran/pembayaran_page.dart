import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/iuran_service.dart';

class PembayaranPage extends StatefulWidget {
  const PembayaranPage({super.key});

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const EdgeInsets _defaultPadding = EdgeInsets.all(8.0);
  static const double _tableCellWidthNo = 50.0;
  static const double _tableCellWidthRumah = 80.0;
  static const double _tableCellWidthNama = 150.0;
  static const double _tableCellWidthBulan = 90.0;
  static const double _tableCellWidthJumlah = 120.0;
  static const double _tableCellWidthStatus = 80.0;
  static const double _tableCellWidthAksi = 120.0;

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

  String _selectedBulan = '';
  int _selectedTahun = DateTime.now().year;
  String _searchQuery = '';

  final List<DocumentSnapshot> _iuranDocs = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;

  Map<String, Map<String, dynamic>> _wargaMap = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedBulan = _bulanList[DateTime.now().month - 1];
    _initData();

    _verticalScrollController.addListener(() {
      if (_verticalScrollController.position.pixels >=
              _verticalScrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          _hasMore) {
        _loadIuran();
      }
    });

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _loadIuran(reset: true); // reset pagination tiap search baru
      });
    });
  }

  Future<void> _initData() async {
    await _loadWarga();
    await _loadIuran(reset: true);
  }

  Future<void> _loadWarga() async {
    final snap = await FirebaseFirestore.instance.collection('warga').get();
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
        .collection('iuran')
        .where('bulan', isEqualTo: _selectedBulan)
        .where('tahun', isEqualTo: _selectedTahun);

    if (_searchQuery.isNotEmpty) {
      // Cari di field gabungan nama+rumah
      query = query
          .where('search_key', isGreaterThanOrEqualTo: _searchQuery)
          .where('search_key', isLessThan: '$_searchQuery\uf8ff');
      query = query.orderBy('search_key');
    } else {
      // Tanpa search, urutkan berdasarkan rumah (ambil dari wargaId)
      query = query.orderBy('wargaId');
    }

    query = query.limit(20);

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

  Future<void> _updateIuranMonth(String iuranId, String bulanBaru) async {
    await FirebaseFirestore.instance.collection('iuran').doc(iuranId).update({
      'bulan': bulanBaru,
    });

    final idx = _iuranDocs.indexWhere((d) => d.id == iuranId);
    if (idx != -1) {
      (_iuranDocs[idx].data() as Map<String, dynamic>)['bulan'] = bulanBaru;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulan iuran diubah ke $bulanBaru')),
      );
      setState(() {});
    }
  }

  Future<void> _showBulanPicker(String iuranId, String current) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Pilih Bulan'),
        children: _bulanList
            .map(
              (b) => SimpleDialogOption(
                onPressed: () => Navigator.pop(c, b),
                child: Text(
                  b,
                  style: TextStyle(
                    fontWeight: b == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null && selected != current) {
      _updateIuranMonth(iuranId, selected);
    }
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

  TableRow _buildDataRow(
    int index,
    Map<String, dynamic> iuranData,
    Map<String, dynamic> wargaData,
    String iuranId,
  ) {
    final status = iuranData['status'];
    final namaWarga = wargaData['nama'] ?? '-';
    final bulanIuran = (iuranData['bulan'] ?? '-').toString();
    final jumlahIuran = iuranData['jumlah'] ?? '0';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.withValues(alpha: 0.05) : null,
      ),
      children: [
        Padding(padding: _defaultPadding, child: Text((index + 1).toString())),
        Padding(
          padding: _defaultPadding,
          child: Text(wargaData['rumah'] ?? '-'),
        ),
        Padding(padding: _defaultPadding, child: Text(namaWarga)),
        Padding(
          padding: _defaultPadding,
          child: status == 'belum'
              ? InkWell(
                  onTap: () => _showBulanPicker(iuranId, bulanIuran),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bulanIuran),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 16, color: Colors.blue),
                    ],
                  ),
                )
              : Text(bulanIuran),
        ),
        Padding(padding: _defaultPadding, child: Text('Rp $jumlahIuran')),
        Padding(
          padding: _defaultPadding,
          child: status == 'lunas'
              ? const Icon(Icons.check, color: Colors.green)
              : const Icon(Icons.close, color: Colors.red),
        ),
        Padding(
          padding: _defaultPadding,
          child: status == 'belum'
              ? ElevatedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Konfirmasi Pembayaran'),
                        content: Text(
                          'Tandai iuran bulan "$bulanIuran" untuk "$namaWarga" sebesar Rp $jumlahIuran sebagai lunas?',
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
                    if (ok == true) {
                      await IuranService().bayar(iuranId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil!')),
                        );
                        setState(() {});
                      }
                    }
                  },
                  child: const Text('Bayar'),
                )
              : const Text('Lunas'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TIDAK ADA FILTER LAGI DI SINI
    final docs = _iuranDocs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Iuran'),
        actions: [
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
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 🔍 SEARCH BAR DI BODY
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau rumah...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 📊 TABLE
                  Expanded(
                    child: docs.isEmpty && !_isLoading
                        ? Center(
                            child: Text(
                              'Tidak ada data iuran untuk $_selectedBulan $_selectedTahun.',
                            ),
                          )
                        : Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Scrollbar(
                                controller: _verticalScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _verticalScrollController,
                                  child: Table(
                                    border: TableBorder.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    columnWidths: const {
                                      0: FixedColumnWidth(_tableCellWidthNo),
                                      1: FixedColumnWidth(_tableCellWidthRumah),
                                      2: FixedColumnWidth(_tableCellWidthNama),
                                      3: FixedColumnWidth(_tableCellWidthBulan),
                                      4: FixedColumnWidth(
                                        _tableCellWidthJumlah,
                                      ),
                                      5: FixedColumnWidth(
                                        _tableCellWidthStatus,
                                      ),
                                      6: FixedColumnWidth(_tableCellWidthAksi),
                                    },
                                    children: [
                                      _buildHeaderRow(),
                                      ...docs.asMap().entries.map((entry) {
                                        final i = entry.key;
                                        final doc = entry.value;
                                        final iuranData =
                                            doc.data() as Map<String, dynamic>;
                                        final wargaData =
                                            _wargaMap[iuranData['wargaId']];

                                        return wargaData == null
                                            ? TableRow(
                                                children: [
                                                  Padding(
                                                    padding: _defaultPadding,
                                                    child: Text(
                                                      (i + 1).toString(),
                                                    ),
                                                  ),
                                                  const Padding(
                                                    padding: _defaultPadding,
                                                    child: Text(
                                                      'Data Warga Tidak Ditemukan',
                                                      style: TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                  ...List.filled(
                                                    5,
                                                    const Padding(
                                                      padding: _defaultPadding,
                                                      child: Text(''),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : _buildDataRow(
                                                i,
                                                iuranData,
                                                wargaData,
                                                doc.id,
                                              );
                                      }),

                                      if (_hasMore)
                                        TableRow(
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                            ...List.filled(
                                              6,
                                              const Padding(
                                                padding: _defaultPadding,
                                                child: Text(''),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
