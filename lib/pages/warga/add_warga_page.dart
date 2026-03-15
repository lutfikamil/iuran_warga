import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddWargaPage extends StatefulWidget {
  final String? wargaId;
  const AddWargaPage({super.key, this.wargaId});

  @override
  State<AddWargaPage> createState() => _AddWargaPageState();
}

class _AddWargaPageState extends State<AddWargaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _rumahController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  String? _selectedStatus;
  final List<String> _statusOptions = [
    'Dihuni',
    'Kosong',
    'Sewa',
  ]; // Opsi status
  bool _isLoading = false;
  bool _isEditing = false;
  @override
  void initState() {
    super.initState();
    if (widget.wargaId != null) {
      _isEditing = true;
      _loadWargaData();
    }
  }

  Future<void> _loadWargaData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("warga")
          .doc(widget.wargaId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _namaController.text = data["nama"] ?? '';
        _rumahController.text = data["rumah"] ?? '';
        _hpController.text = data["hp"] ?? '';
        _selectedStatus = data["status"] ?? _statusOptions.first;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data warga: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveWarga() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final Map<String, dynamic> wargaData = {
          "nama": _namaController.text,
          "rumah": _rumahController.text,
          "hp": _hpController.text,
          "status": _selectedStatus,
          "updatedAt": Timestamp.now(),
        };
        if (_isEditing) {
          await FirebaseFirestore.instance
              .collection("warga")
              .doc(widget.wargaId)
              .update(wargaData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Warga berhasil diperbarui!')),
            );
          }
        } else {
          wargaData["createdAt"] = Timestamp.now(); // Hanya saat membuat baru
          await FirebaseFirestore.instance.collection("warga").add(wargaData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Warga berhasil ditambahkan!')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(context); // Kembali ke halaman sebelumnya
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan warga: $e')));
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
    _namaController.dispose();
    _rumahController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Warga Baru")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Warga',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _rumahController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Rumah',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor rumah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _hpController,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor hp tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                // <<< Tambahkan Dropdown ini
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Rumah',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Status rumah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24.0),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveWarga,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _isEditing ? 'Update Warga' : 'Simpan Warga',
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
