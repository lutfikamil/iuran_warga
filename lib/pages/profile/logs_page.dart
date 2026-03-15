import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/log_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  static const EdgeInsets _tableCellPadding = EdgeInsets.all(8.0);

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  TableRow _buildHeaderRow(BuildContext context) {
    TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );

    Widget headerCell(String value, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: _tableCellPadding,
        child: Text(value, textAlign: align, style: headerStyle),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      children: [
        headerCell('No', align: TextAlign.center),
        headerCell('Tanggal', align: TextAlign.center),
        headerCell('User', align: TextAlign.center),
        headerCell('Aksi'),
        headerCell('Target'),
        headerCell('Detail'),
      ],
    );
  }

  TableRow _buildDataRow(int index, Map<String, dynamic> log) {
    final Timestamp? timestamp = log['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate();
    final formatted = dateTime != null
        ? DateFormat('dd MMM yyyy HH:mm:ss').format(dateTime)
        : '-';

    Widget cell(String value, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: _tableCellPadding,
        child: Text(value, textAlign: align),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.shade50 : Colors.white,
      ),
      children: [
        cell((index + 1).toString(), align: TextAlign.center),
        cell(formatted, align: TextAlign.center),
        cell(log['actorRole']?.toString() ?? '-'),
        cell(log['action']?.toString() ?? '-'),
        cell(log['target']?.toString() ?? '-'),
        cell(log['detail']?.toString() ?? '-'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: LogService().streamLogs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat logs: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada catatan logs.'));
        }

        final logs = docs
            .map((doc) => (doc.data() as Map<String, dynamic>)..['id'] = doc.id)
            .toList();

        return Padding(
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
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FixedColumnWidth(50),
                      1: FixedColumnWidth(170),
                      2: FixedColumnWidth(100),
                      3: FixedColumnWidth(140),
                      4: FixedColumnWidth(140),
                      5: FixedColumnWidth(420),
                    },
                    children: [
                      _buildHeaderRow(context),
                      ...List.generate(
                        logs.length,
                        (index) => _buildDataRow(index, logs[index]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
