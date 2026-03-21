import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WargaKeluarPage extends StatelessWidget {
  const WargaKeluarPage({super.key});

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value.toDate());
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arsip Warga Keluar')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('warga_keluar')
            .orderBy('archivedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada arsip warga keluar.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Card(
                child: ListTile(
                  title: Text(data['nama']?.toString() ?? '-'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text('Rumah terakhir: ${data['rumahTerakhir'] ?? '-'}'),
                      Text('Status keluar: ${data['statusKeluar'] ?? '-'}'),
                      Text('HP: ${data['hp'] ?? '-'}'),
                      Text('Diarsipkan: ${_formatTimestamp(data['archivedAt'])}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
