import 'package:flutter/material.dart';
import '../../widgets/dashboard/status_pembayaran_table.dart';

class DaftarIuranPage extends StatelessWidget {
  const DaftarIuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Iuran Warga")),
      body: Column(
        // Menggunakan Column karena StatusPembayaranTable sekarang mengelola padding dan search bar-nya sendiri
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul "Status Pembayaran" sekarang bisa opsional, atau diatur di sini
          // Jika StatusPembayaranTable sudah punya search, section ini bisa dibuang/diubah
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: const Text(
              "Daftar Pembayaran Iuran Warga", // Judul yang lebih spesifik untuk halaman ini
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            // Expanded agar StatusPembayaranTable mengisi sisa ruang
            child:
                StatusPembayaranTable(), // Cukup panggil StatusPembayaranTable
          ),
        ],
      ),
    );
  }
}
