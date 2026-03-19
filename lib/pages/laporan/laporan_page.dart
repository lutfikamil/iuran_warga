import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/log_service.dart';
import 'export_laporan_page.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  DateTime? _selectedDate;
  String _filterType = 'Detail';
  final List<String> _selectedTransactionIds = [];

  Future<void> _pickMonthYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        if (_filterType == 'Global') _filterType = 'Bulanan';
      });
    }
  }

  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  Future<void> _approveSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih setidaknya satu transaksi untuk disetujui.'),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Menerima Transaksi'),
        content: Text(
          'Apakah Anda yakin menerima ${_selectedTransactionIds.length} transaksi terpilih?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        for (String trxId in _selectedTransactionIds) {
          final trxRef = FirebaseFirestore.instance
              .collection("transaksi")
              .doc(trxId);
          batch.update(trxRef, {
            'statusBendahara': 'diterima',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await LogService().logEvent(
          action: 'approve_transaksi',
          target: 'transaksi',
          detail: 'Menerima ${_selectedTransactionIds.length} transaksi',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedTransactionIds.length} transaksi berhasil diterima!',
              ),
            ),
          );
          setState(() {
            _selectedTransactionIds.clear();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menerima transaksi: $e')),
          );
        }
      }
    }
  }

  /// Ambil data transaksi sesuai filter + hitung saldo berjalan
  Future<List<Map<String, dynamic>>> getTransactions() async {
    Query transactionQuery = FirebaseFirestore.instance.collection("transaksi");

    if (_filterType == 'Bulanan' && _selectedDate != null) {
      final startOfMonth = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedDate!.year,
        _selectedDate!.month + 1,
        0,
        23,
        59,
        59,
      );
      transactionQuery = transactionQuery
          .where('tanggal', isGreaterThanOrEqualTo: startOfMonth)
          .where('tanggal', isLessThanOrEqualTo: endOfMonth);
    } else if (_filterType == 'Tahunan' && _selectedDate != null) {
      final startOfYear = DateTime(_selectedDate!.year, 1, 1);
      final endOfYear = DateTime(_selectedDate!.year, 12, 31, 23, 59, 59);
      transactionQuery = transactionQuery
          .where('tanggal', isGreaterThanOrEqualTo: startOfYear)
          .where('tanggal', isLessThanOrEqualTo: endOfYear);
    }

    final snapshot = await transactionQuery.orderBy('tanggal').get();

    List<Map<String, dynamic>> allTransactions = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      allTransactions.add({
        'id': doc.id,
        'tanggal': data['tanggal'],
        'jenis': data['jenis'] ?? 'masuk',
        'jumlah': data['jumlah'] ?? 0,
        'dari': data['dari'] ?? '-',
        'penerima': data['penerima'] ?? '-',
        'keterangan': data['keterangan'] ?? '-',
        'statusBendahara': data['statusBendahara'] ?? 'menunggu',
      });
    }

    double currentBalance = 0.0;
    List<Map<String, dynamic>> transactionsWithBalance = [];
    for (var trx in allTransactions) {
      if (trx['jenis'] == 'masuk') {
        currentBalance += (trx['jumlah'] as num).toDouble();
      } else {
        currentBalance -= (trx['jumlah'] as num).toDouble();
      }
      transactionsWithBalance.add({...trx, 'currentBalance': currentBalance});
    }

    return transactionsWithBalance;
  }

  static const EdgeInsets _tableCellPadding = EdgeInsets.all(8.0);
  static const double _colWidthNo = 50.0;
  static const double _colWidthTanggal = 100.0;
  static const double _colWidthJenis = 80.0;
  static const double _colWidthMasukKeluar = 100.0;
  static const double _colWidthDariPenerima = 120.0;
  static const double _colWidthKeterangan = 200.0;
  static const double _colWidthStatusAksi = 80.0;

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      ),
      children: [
        _buildHeaderCell("No", textAlign: TextAlign.center),
        _buildHeaderCell("Tanggal", textAlign: TextAlign.center),
        _buildHeaderCell("Jenis", textAlign: TextAlign.center),
        _buildHeaderCell("Masuk", textAlign: TextAlign.center),
        _buildHeaderCell("Keluar", textAlign: TextAlign.center),
        _buildHeaderCell("Saldo", textAlign: TextAlign.center),
        _buildHeaderCell("Dari", textAlign: TextAlign.center),
        _buildHeaderCell("Penerima", textAlign: TextAlign.center),
        _buildHeaderCell("Keterangan", textAlign: TextAlign.center),
        _buildHeaderCell("Aksi", textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildHeaderCell(
    String text, {
    TextAlign textAlign = TextAlign.center,
  }) {
    return Padding(
      padding: _tableCellPadding,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    int index,
    Map<String, dynamic> transaction,
    double currentBalance,
  ) {
    final String trxId = transaction['id'];
    final bool isMasuk = transaction['jenis'] == 'masuk';
    final num jumlah = (transaction['jumlah'] as num?) ?? 0;
    final String dari = transaction['dari'] ?? '-';
    final String penerima = transaction['penerima'] ?? '-';
    final String keterangan = transaction['keterangan'] ?? '-';
    final String statusBendahara = transaction['statusBendahara'] ?? 'menunggu';
    final bool isSelected = _selectedTransactionIds.contains(trxId);
    final bool isApproved = statusBendahara == 'diterima';

    Timestamp? ts = transaction['tanggal'] as Timestamp?;
    DateTime? tanggal = ts?.toDate();
    String tanggalFormatted = tanggal != null
        ? DateFormat('dd MMM yyyy').format(tanggal)
        : '-';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.shade50 : Colors.white,
      ),
      children: [
        Padding(
          padding: _tableCellPadding,
          child: Text((index + 1).toString(), textAlign: TextAlign.center),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(tanggalFormatted, textAlign: TextAlign.center),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(
            isMasuk ? 'Masuk' : 'Keluar',
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(
            isMasuk ? formatRupiah(jumlah) : '',
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(
            !isMasuk ? formatRupiah(jumlah) : '',
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(formatRupiah(currentBalance), textAlign: TextAlign.right),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(dari, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(penerima, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Text(keterangan, textAlign: TextAlign.left),
        ),
        Padding(
          padding: _tableCellPadding,
          child: Checkbox(
            value: isSelected || isApproved,
            onChanged: isApproved
                ? null
                : (bool? newValue) {
                    setState(() {
                      if (newValue == true) {
                        _selectedTransactionIds.add(trxId);
                      } else {
                        _selectedTransactionIds.remove(trxId);
                      }
                    });
                  },
            tristate: false,
            activeColor: isApproved
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Query transactionQuery = FirebaseFirestore.instance.collection("transaksi");

    if (_filterType == 'Bulanan' && _selectedDate != null) {
      final startOfMonth = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedDate!.year,
        _selectedDate!.month + 1,
        0,
        23,
        59,
        59,
      );
      transactionQuery = transactionQuery
          .where('tanggal', isGreaterThanOrEqualTo: startOfMonth)
          .where('tanggal', isLessThanOrEqualTo: endOfMonth);
    } else if (_filterType == 'Tahunan' && _selectedDate != null) {
      final startOfYear = DateTime(_selectedDate!.year, 1, 1);
      final endOfYear = DateTime(_selectedDate!.year, 12, 31, 23, 59, 59);
      transactionQuery = transactionQuery
          .where('tanggal', isGreaterThanOrEqualTo: startOfYear)
          .where('tanggal', isLessThanOrEqualTo: endOfYear);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Keuangan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Laporan',
            onPressed: () async {
              final data = await getTransactions();
              if (!context.mounted) return;
              if (data.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tidak ada data untuk di-export'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExportLaporanPage(
                    transactions: data,
                    filterType: _filterType,
                    selectedDate: _selectedDate,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Setujui Transaksi Terpilih',
            onPressed: _approveSelectedTransactions,
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                _filterType = value;
                if (value == 'Bulanan' || value == 'Tahunan') {
                  _pickMonthYear(context);
                } else {
                  _selectedDate = null;
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Global',
                child: Text('Global'),
              ),
              const PopupMenuItem<String>(
                value: 'Bulanan',
                child: Text('Bulanan'),
              ),
              const PopupMenuItem<String>(
                value: 'Tahunan',
                child: Text('Tahunan'),
              ),
            ],
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Laporan',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: transactionQuery.orderBy('tanggal').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> allTransactions = [];
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            allTransactions.add({
              'id': doc.id,
              'tanggal': data['tanggal'],
              'jenis': data['jenis'] ?? 'masuk',
              'jumlah': data['jumlah'] ?? 0,
              'dari': data['dari'] ?? '-',
              'penerima': data['penerima'] ?? '-',
              'keterangan': data['keterangan'] ?? '-',
              'statusBendahara': data['statusBendahara'] ?? 'menunggu',
            });
          }

          double currentBalance = 0.0;
          List<Map<String, dynamic>> transactionsWithBalance = [];
          for (var trx in allTransactions) {
            if (trx['jenis'] == 'masuk') {
              currentBalance += (trx['jumlah'] as num).toDouble();
            } else {
              currentBalance -= (trx['jumlah'] as num).toDouble();
            }
            transactionsWithBalance.add({
              ...trx,
              'currentBalance': currentBalance,
            });
          }

          if (transactionsWithBalance.isEmpty) {
            return const Center(
              child: Text('Tidak ada transaksi untuk periode ini.'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Laporan: $_filterType${_selectedDate != null ? ' (${DateFormat('MMMM yyyy').format(_selectedDate!)})' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Scrollbar(
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
                              0: FixedColumnWidth(_colWidthNo),
                              1: FixedColumnWidth(_colWidthTanggal),
                              2: FixedColumnWidth(_colWidthJenis),
                              3: FixedColumnWidth(_colWidthMasukKeluar),
                              4: FixedColumnWidth(_colWidthMasukKeluar),
                              5: FixedColumnWidth(_colWidthMasukKeluar),
                              6: FixedColumnWidth(_colWidthDariPenerima),
                              7: FixedColumnWidth(_colWidthDariPenerima),
                              8: FixedColumnWidth(_colWidthKeterangan),
                              9: FixedColumnWidth(_colWidthStatusAksi),
                            },
                            children: [
                              _buildHeaderRow(),
                              ...List.generate(transactionsWithBalance.length, (
                                index,
                              ) {
                                final transaction =
                                    transactionsWithBalance[index];
                                final double balanceAfterThisTrx =
                                    (transaction['currentBalance'] as num)
                                        .toDouble();

                                return _buildDataRow(
                                  index,
                                  transaction,
                                  balanceAfterThisTrx,
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
    );
  }
}
