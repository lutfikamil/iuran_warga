// File: lib/pages/pengeluaran/add_pengeluaran_page.dart (Buat file baru)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/pengeluaran_service.dart';

class AddPengeluaranPage extends StatefulWidget {
  final String? pengeluaranId; // ID pengeluaran jika mode edit

  const AddPengeluaranPage({super.key, this.pengeluaranId});

  @override
  State<AddPengeluaranPage> createState() => _AddPengeluaranPageState();
}

class _AddPengeluaranPageState extends State<AddPengeluaranPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _dariController = TextEditingController();
  final TextEditingController _penerimaController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  DateTime _selectedTanggal = DateTime.now();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.pengeluaranId!= null) {
      _isEditing = true;
      _loadPengeluaranData();
    }
  }

  // Memuat data pengeluaran jika mode edit
  Future<void> _loadPengeluaranData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
         .collection("transaksi")
         .doc(widget.pengeluaranId)
         .get();

      if (doc.exists && doc.data() is Map<String, dynamic>) {
        final data = doc.data() as Map<String, dynamic>;
        _jumlahController.text = (data['jumlah'] as num?)?.toString()?? '';
        _dariController.text = data['dari']?? '';
        _penerimaController.text = data['penerima']?? '';
        _keteranganController.text = data['keterangan']?? '';
        _selectedTanggal = (data['tanggal'] as Timestamp?)?.toDate()?? DateTime.now();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pengeluaran: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk memilih tanggal
  Future<void> _selectTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked!= null && picked!= _selectedTanggal) {
      setState(() {
        _selectedTanggal = picked;
      });
    }
  }

  // Menyimpan atau memperbarui pengeluaran
  Future<void> _savePengeluaran() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final double jumlah = double.parse(_jumlahController.text);

        if (_isEditing) {
          await PengeluaranService().updatePengeluaran(
            id: widget.pengeluaranId!,
            tanggal: _selectedTanggal,
            jumlah: jumlah,
            dari: _dariController.text,
            penerima: _penerimaController.text,
            keterangan: _keteranganController.text,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pengeluaran berhasil diperbarui!')),
            );
          }
        } else {
          await PengeluaranService().addPengeluaran(
            tanggal: _selectedTanggal,
            jumlah: jumlah,
            dari: _dariController.text,
            penerima: _penerimaController.text,
            keterangan: _keteranganController.text,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pengeluaran berhasil ditambahkan!')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan pengeluaran: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _dariController.dispose();
    _penerimaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing? "Edit Pengeluaran" : "Tambah Pengeluaran"),
      ),
      body: _isLoading && _isEditing
         ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Tanggal ---
                    ListTile(
                      title: Text(
                        'Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedTanggal)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectTanggal(context),
                    ),
                    const SizedBox(height: 16.0),

                    // --- Jumlah ---
                    TextFormField(
                      controller: _jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah (Rp)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Jumlah tidak boleh kosong';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Jumlah harus berupa angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // --- Dari ---
                    TextFormField(
                      controller: _dariController,
                      decoration: const InputDecoration(
                        labelText: 'Dari (Sumber Dana)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Sumber dana tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // --- Penerima ---
                    TextFormField(
                      controller: _penerimaController,
                      decoration: const InputDecoration(
                        labelText: 'Penerima Pengeluaran',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Penerima tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // --- Keterangan ---
                    TextFormField(
                      controller: _keteranganController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan (Opsional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // --- Tombol Simpan ---
                    _isLoading &&!_isEditing
                       ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _savePengeluaran,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isEditing? 'Perbarui Pengeluaran' : 'Tambah Pengeluaran',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}