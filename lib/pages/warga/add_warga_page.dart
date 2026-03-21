import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/iuran_service.dart';
import '../../services/log_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/users_service.dart';
import '../../services/warga_lifecycle_service.dart';

class AddWargaPage extends StatefulWidget {
  final String? wargaId;
  const AddWargaPage({super.key, this.wargaId});

  @override
  State<AddWargaPage> createState() => _AddWargaPageState();
}

class _AddWargaPageState extends State<AddWargaPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _rumahController = TextEditingController();
  final _hpController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedStatus;
  String _selectedRole = 'warga';
  bool _isIuranAktifUntukRumahKosong = false;

  final List<String> _statusOptions = ['Dihuni', 'Kosong', 'Sewa'];
  final List<String> _roleOptions = [
    'ketua',
    'bendahara',
    'sekertaris',
    'petugas',
    'pengurus_musolah',
    'warga',
  ];

  bool _isLoading = false;
  bool _isEditing = false;
  int _generatedIuranCount = 0;

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
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('warga')
          .doc(widget.wargaId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _namaController.text = data['nama'] ?? '';
        _rumahController.text = data['rumah'] ?? '';
        _hpController.text = data['hp'] ?? '';
        _selectedStatus = data['status'] ?? _statusOptions.first;
        _selectedRole = (data['role'] ?? 'warga').toString().toLowerCase();
        _isIuranAktifUntukRumahKosong =
            data['status']?.toString().toLowerCase() == 'kosong' &&
            data['iuranAktif'] == true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal load: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWarga() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _generatedIuranCount = 0;

    try {
      final nama = _namaController.text.trim();
      final rumahData = WargaLifecycleService().normalizeRumahData(
        _rumahController.text.trim(),
      );

      final rumah = rumahData['rumah'];
      final blok = rumahData['blok'];
      final nomor = rumahData['nomor'];
      final hp = _hpController.text.trim();

      final identifier = _resolveIdentifier();
      final email = "$identifier@mulialand.com";

      final inputPassword = _passwordController.text.trim();
      final password = inputPassword.isNotEmpty
          ? inputPassword
          : (_isEditing ? null : generateRandomPassword());

      final isRumahKosong = (_selectedStatus ?? '').toLowerCase() == 'kosong';

      final wargaData = <String, dynamic>{
        'nama': nama,
        'rumah': rumah,
        'blok': blok,
        'nomor': nomor,
        'hp': hp,
        'status': _selectedStatus,
        'iuranAktif': isRumahKosong ? _isIuranAktifUntukRumahKosong : true,
        'role': _selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      String wargaId;

      if (_isEditing) {
        /// ================= UPDATE =================
        wargaId = widget.wargaId!;

        await FirebaseFirestore.instance
            .collection('warga')
            .doc(wargaId)
            .update(wargaData);

        /// 🔥 update user login juga
        await upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          hp: hp,
          role: _selectedRole,
          identifier: identifier,
          newRawPassword: password,
        );

        await LogService().logEvent(
          action: 'update_warga',
          target: 'warga',
          detail: 'Update warga $nama',
        );
      } else {
        /// ================= CREATE =================

        /// 🔥 buat ID sendiri (bukan dari auth)
        final newDoc = FirebaseFirestore.instance.collection('warga').doc();
        wargaId = newDoc.id;

        /// simpan warga
        await newDoc.set({
          ...wargaData,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final generatedCount = await IuranService()
            .generateIuranMulaiBulanBerikutnyaUntukWargaBaru(wargaId: wargaId);
        _generatedIuranCount = generatedCount;

        /// 🔥 buat user login (PUSAT LOGIKA)
        await upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          hp: hp,
          role: _selectedRole,
          identifier: identifier,
          newRawPassword: password,
        );

        await LogService().logEvent(
          action: 'tambah_warga',
          target: 'warga',
          detail:
              'Tambah warga $nama'
              '${generatedCount > 0 ? ' dan generate $generatedCount iuran susulan' : ''}',
        );
      }

      /// =========================================
      /// 🔥 AUTO KIRIM WHATSAPP
      /// =========================================
      if (hp.isNotEmpty && password != null) {
        final message =
            '''
Halo Bapak/Ibu $nama

Akun Anda telah dibuat.
Untuk mengetahui Informasi pembayaran iuran Anda dan
Keadaan keuangan di Perumahan kita tercinta ini.

  Login:
Email: $email
Password: $password

Silakan login dan segera ganti password.
Jika ada pertanyaan jangan sungkan untuk menghubungi kami baik di Group atau DM langsung.

Terima kasih
Pengurus Perumahan Mulia Land Patria. 
''';

        try {
          await WhatsappService.sendMessage(phone: hp, message: message);
        } catch (e) {
          debugPrint('Gagal kirim WA: $e');
        }
      }

      /// =========================================
      /// 🔔 NOTIFIKASI
      /// =========================================
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Berhasil update warga'
                  : _generatedIuranCount > 0
                  ? 'Berhasil tambah warga dan generate $_generatedIuranCount iuran susulan'
                  : 'Berhasil tambah warga',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Warga' : 'Tambah Warga')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rumahController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Rumah',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hpController,
                decoration: const InputDecoration(
                  labelText: 'No HP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
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
                    final previousStatus = _selectedStatus;
                    _selectedStatus = newValue;
                    if ((newValue ?? '').toLowerCase() == 'kosong' &&
                        (previousStatus ?? '').toLowerCase() != 'kosong') {
                      _isIuranAktifUntukRumahKosong = false;
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Status rumah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              if ((_selectedStatus ?? '').toLowerCase() == 'kosong') ...[
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan iuran untuk rumah kosong'),
                  subtitle: const Text(
                    'Default nonaktif. Nyalakan bila rumah kosong ini tetap dikenakan iuran.',
                  ),
                  value: _isIuranAktifUntukRumahKosong,
                  onChanged: (value) {
                    setState(() {
                      _isIuranAktifUntukRumahKosong = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roleOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Password baru (opsional)'
                      : 'Password (opsional)',
                  hintText: _isEditing
                      ? 'Kosongkan jika tidak ingin mengubah password'
                      : 'Kosongkan untuk password random otomatis',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'Min 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveWarga,
                      child: Text(_isEditing ? 'Update' : 'Simpan'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
