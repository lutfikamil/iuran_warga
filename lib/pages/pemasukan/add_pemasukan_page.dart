import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pemasukan_service.dart';

class AddPemasukanPage extends StatefulWidget {
  final String? pemasukanId;

  const AddPemasukanPage({super.key, this.pemasukanId});

  @override
  State<AddPemasukanPage> createState() => _AddPemasukanPageState();
}

class _AddPemasukanPageState extends State<AddPemasukanPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _dariController = TextEditingController();
  final _penerimaController = TextEditingController(text: 'Bendahara');
  final _keteranganController = TextEditingController();

  DateTime _selectedTanggal = DateTime.now();
  bool _isLoading = false;

  bool get _isEditing => widget.pemasukanId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadPemasukanData();
    }
  }

  Future<void> _loadPemasukanData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transaksi')
          .doc(widget.pemasukanId)
          .get();

      if (!doc.exists) {
        throw Exception('Data pemasukan tidak ditemukan');
      }

      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? tanggalTimestamp = data['tanggal'] as Timestamp?;

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedTanggal = tanggalTimestamp?.toDate() ?? DateTime.now();
        _jumlahController.text = (data['jumlah'] ?? '').toString();
        _dariController.text = (data['dari'] ?? '').toString();
        _penerimaController.text = (data['penerima'] ?? 'Bendahara').toString();
        _keteranganController.text = (data['keterangan'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data pemasukan: $e')),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedTanggal) {
      setState(() {
        _selectedTanggal = picked;
      });
    }
  }

  Future<void> _savePemasukan() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final jumlah = double.parse(_jumlahController.text);

      if (_isEditing) {
        await PemasukanService().updatePemasukan(
          id: widget.pemasukanId!,
          tanggal: _selectedTanggal,
          jumlah: jumlah,
          dari: _dariController.text.trim(),
          penerima: _penerimaController.text.trim(),
          keterangan: _keteranganController.text.trim(),
        );
      } else {
        await PemasukanService().addPemasukan(
          tanggal: _selectedTanggal,
          jumlah: jumlah,
          dari: _dariController.text.trim(),
          penerima: _penerimaController.text.trim(),
          keterangan: _keteranganController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Pemasukan umum berhasil diperbarui!'
                : 'Pemasukan umum berhasil ditambahkan!',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pemasukan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        title: Text(_isEditing ? 'Edit Pemasukan Umum' : 'Tambah Pemasukan Umum'),
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      title: Text(
                        'Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedTanggal)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectTanggal(context),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah (Rp)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Jumlah tidak boleh kosong';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null) {
                          return 'Jumlah harus berupa angka';
                        }
                        if (parsed <= 0) {
                          return 'Jumlah harus lebih besar dari 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dariController,
                      decoration: const InputDecoration(
                        labelText: 'Sumber Pemasukan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Sumber pemasukan tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _penerimaController,
                      decoration: const InputDecoration(
                        labelText: 'Penerima',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Penerima tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keteranganController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan (Opsional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _isLoading && !_isEditing
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _savePemasukan,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isEditing
                                  ? 'Perbarui Pemasukan Umum'
                                  : 'Tambah Pemasukan Umum',
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
