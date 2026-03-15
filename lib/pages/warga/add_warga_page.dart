import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/log_service.dart';

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
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedStatus;
  String _selectedRole = 'warga';

  final List<String> _statusOptions = ['Dihuni', 'Kosong', 'Sewa'];
  final List<String> _roleOptions = [
    'ketua',
    'bendahara',
    'sekertaris',
    'petugas',
    'warga',
  ];

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

  String _resolveIdentifier() {
    final hp = _hpController.text.trim();
    if (hp.isNotEmpty) return hp;
    return _rumahController.text.trim();
  }

  Future<void> _loadWargaData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('warga')
          .doc(widget.wargaId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _namaController.text = data['nama'] ?? '';
        _rumahController.text = data['rumah'] ?? '';
        _hpController.text = data['hp'] ?? '';
        _selectedStatus = data['status'] ?? _statusOptions.first;
        _selectedRole = (data['role'] ?? 'warga').toString().toLowerCase();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat data warga: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _upsertUserLogin({
    required String wargaId,
    required String nama,
    required String rumah,
    required String hp,
    required String role,
    required String identifier,
    String? newRawPassword,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final batch = FirebaseFirestore.instance.batch();

    final byWarga = await usersRef.where('wargaId', isEqualTo: wargaId).limit(1).get();

    DocumentReference userDocRef;
    Map<String, dynamic> currentData = {};

    if (byWarga.docs.isNotEmpty) {
      userDocRef = byWarga.docs.first.reference;
      currentData = byWarga.docs.first.data();
    } else {
      final byIdentifier = await usersRef
          .where('identifier', isEqualTo: identifier)
          .limit(1)
          .get();

      if (byIdentifier.docs.isNotEmpty) {
        userDocRef = byIdentifier.docs.first.reference;
        currentData = byIdentifier.docs.first.data();
      } else {
        userDocRef = usersRef.doc();
      }
    }

    final passwordHash = (newRawPassword != null && newRawPassword.isNotEmpty)
        ? AuthService().hashPassword(newRawPassword)
        : (currentData['password'] ?? AuthService().hashPassword('123456'));

    batch.set(userDocRef, {
      'wargaId': wargaId,
      'nama': nama,
      'rumah': rumah,
      'hp': hp,
      'identifier': identifier,
      'role': role,
      'password': passwordHash,
      'updatedAt': Timestamp.now(),
      'createdAt': currentData['createdAt'] ?? Timestamp.now(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _saveWarga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nama = _namaController.text.trim();
      final rumah = _rumahController.text.trim();
      final hp = _hpController.text.trim();
      final identifier = _resolveIdentifier();

      final wargaData = <String, dynamic>{
        'nama': nama,
        'rumah': rumah,
        'hp': hp,
        'status': _selectedStatus,
        'role': _selectedRole,
        'updatedAt': Timestamp.now(),
      };

      String wargaId = widget.wargaId ?? '';

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('warga')
            .doc(widget.wargaId)
            .update(wargaData);

        wargaId = widget.wargaId!;

        await _upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          hp: hp,
          role: _selectedRole,
          identifier: identifier,
          newRawPassword: _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text.trim(),
        );

        await LogService().logEvent(
          action: 'update_warga',
          target: 'warga',
          detail: 'Update data warga $nama (id=$wargaId) + sinkron akun login',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warga & akun login berhasil diperbarui!'),
            ),
          );
        }
      } else {
        wargaData['createdAt'] = Timestamp.now();
        final ref = await FirebaseFirestore.instance
            .collection('warga')
            .add(wargaData);

        wargaId = ref.id;

        await _upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          hp: hp,
          role: _selectedRole,
          identifier: identifier,
          newRawPassword: _passwordController.text.trim(),
        );

        await LogService().logEvent(
          action: 'tambah_warga',
          target: 'warga',
          detail: 'Tambah warga $nama (id=$wargaId) + buat akun login',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warga & akun login berhasil ditambahkan!'),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan warga: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _rumahController.dispose();
    _hpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Warga' : 'Tambah Warga Baru')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Warga',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rumahController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Rumah',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nomor rumah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hpController,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP (dipakai sebagai identifier login)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) &&
                      _rumahController.text.trim().isEmpty) {
                    return 'Isi nomor HP atau nomor rumah untuk identifier login';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Rumah',
                  border: OutlineInputBorder(),
                ),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (newValue) {
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role Login User',
                  border: OutlineInputBorder(),
                ),
                items: _roleOptions.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue == null) return;
                  setState(() {
                    _selectedRole = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Password Baru (opsional, kosongkan jika tidak ganti)'
                      : 'Password Login User',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (!_isEditing && text.isEmpty) {
                    return 'Password wajib diisi';
                  }
                  if (text.isNotEmpty && text.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Identifier login otomatis memakai No HP. Jika kosong, pakai No Rumah.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveWarga,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _isEditing ? 'Update Warga & Akun' : 'Simpan Warga & Buat Akun',
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
