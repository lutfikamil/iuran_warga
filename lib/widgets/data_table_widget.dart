import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataTableWidget extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const DataTableWidget({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: DataTable(
        columns: const [
          DataColumn(label: Text("Rumah")),
          DataColumn(label: Text("Bulan")),
          DataColumn(label: Text("Jumlah")),
          DataColumn(label: Text("Status")),
        ],

        rows: docs.map((d) {
          return DataRow(
            cells: [
              DataCell(Text(d["warga"].toString())),
              DataCell(Text(d["bulan"].toString())),
              DataCell(Text("Rp ${d["jumlah"]}")),
              DataCell(Text(d["status"])),
            ],
          );
        }).toList(),
      ),
    );
  }
}
