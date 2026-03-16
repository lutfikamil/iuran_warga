// File: lib/pages/laporan/laporan_page.dart (Refactor Total)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/log_service.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  DateTime? _selectedDate; // Untuk filter bulan/tahun
  String _filterType = 'Global'; // 'Global', 'Bulanan', 'Tahunan'

  // List untuk menyimpan ID transaksi yang dipilih untuk aksi (checkbox)
  List<String> _selectedTransactionIds = [];

  // --- Fungsi untuk memilih bulan/tahun ---
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
        // Default ke bulanan jika tanggal dipilih, user bisa ganti ke Tahunan
        if (_filterType == 'Global') _filterType = 'Bulanan';
      });
    }
  }

  // --- Fungsi untuk mengformat Rupiah ---
  String formatRupiah(num number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  // --- Fungsi untuk meng-update status bendahara transaksi terpilih ---
  Future<void> _approveSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih setidaknya satu transaksi untuk disetujui.'),
        ),
      );
      return;
    }

    // Konfirmasi sebelum eksekusi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui Transaksi'),
        content: Text(
          'Apakah Anda yakin ingin menyetujui ${_selectedTransactionIds.length} transaksi terpilih?',
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
          detail: 'Menyetujui ${_selectedTransactionIds.length} transaksi',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedTransactionIds.length} transaksi berhasil disetujui!',
              ),
            ),
          );
          setState(() {
            _selectedTransactionIds
                .clear(); // Bersihkan pilihan setelah disetujui
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyetujui transaksi: $e')),
          );
        }
      }
    }
  }

  // --- Konstanta untuk styling tabel ---
  static const EdgeInsets _tableCellPadding = EdgeInsets.all(8.0);
  static const double _colWidthNo = 50.0;
  static const double _colWidthTanggal = 100.0;
  static const double _colWidthJenis = 80.0;
  static const double _colWidthMasukKeluar =
      100.0; // Untuk Masuk, Keluar, Saldo
  static const double _colWidthDariPenerima = 120.0; // Untuk Dari, Penerima
  static const double _colWidthKeterangan = 200.0;
  static const double _colWidthStatusAksi = 80.0;

  /// HEADER ROW TABLE
  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      children: [
        _buildHeaderCell("No", textAlign: TextAlign.center),
        _buildHeaderCell("Tanggal", textAlign: TextAlign.center),
        _buildHeaderCell("Jenis", textAlign: TextAlign.center),
        _buildHeaderCell("Masuk", textAlign: TextAlign.right),
        _buildHeaderCell("Keluar", textAlign: TextAlign.right),
        _buildHeaderCell("Saldo", textAlign: TextAlign.right),
        _buildHeaderCell("Dari", textAlign: TextAlign.left),
        _buildHeaderCell("Penerima", textAlign: TextAlign.left),
        _buildHeaderCell("Keterangan", textAlign: TextAlign.left),
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

  /// DATA ROW TABLE
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

    // Format tanggal
    Timestamp? ts = transaction['tanggal'] as Timestamp?;
    DateTime? tanggal = ts?.toDate();
    String tanggalFormatted = tanggal != null
        ? DateFormat('dd MMM yyyy').format(tanggal)
        : '-';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.grey.shade50
            : Colors.white, // Zebra stripe
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
            value:
                isSelected ||
                isApproved, // Jika sudah diterima, checkbox juga aktif
            onChanged: isApproved
                ? null
                : (bool? newValue) {
                    // Tidak bisa mengubah jika sudah diterima
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
                  _selectedDate = null; // Clear selected date for Global
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
              'jenis': data['jenis'] ?? 'masuk', // Default ke masuk jika kosong
              'jumlah': data['jumlah'] ?? 0,
              'dari': data['dari'] ?? '-',
              'penerima': data['penerima'] ?? '-',
              'keterangan': data['keterangan'] ?? '-',
              'statusBendahara': data['statusBendahara'] ?? 'menunggu',
            });
          }

          // Hitung saldo berjalan
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
              // Menampilkan filter yang aktif
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
