import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/iuran_service.dart';
import '../../services/log_service.dart';
import '../../services/sekretaris_sync_service.dart';
import '../../services/session_service.dart';
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
  bool _isIuranAktif = true;

  final List<String> _statusOptions = ['Dihuni', 'Kosong', 'Sewa'];
  final List<String> _roleOptions = [
    'ketua',
    'bendahara',
    'sekretaris',
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
        _hpController.text = data['noHpPenghuni'] ?? '';
        _selectedStatus = data['status'] ?? _statusOptions.first;
        _selectedRole = AuthService.normalizeRole(
          data['role']?.toString() ?? 'warga',
        );
        final isRumahKosong =
            data['status']?.toString().toLowerCase() == 'kosong';
        _isIuranAktif = isRumahKosong
            ? data['iuranAktif'] == true
            : data['iuranAktif'] != false;
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

      final inputPassword = _passwordController.text.trim();
      final password = inputPassword.isNotEmpty
          ? inputPassword
          : (_isEditing ? null : generateRandomPassword());

      final wargaData = <String, dynamic>{
        'nama': nama,
        'rumah': rumah,
        'blok': blok,
        'nomor': nomor,
        'noHpPenghuni': hp,
        'status': _selectedStatus,
        'iuranAktif': _isIuranAktif,
        'role': _selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      String wargaId;
      late final ResidentAccountProvisionResult accountResult;
      AdminResidentPasswordResetResult? resetResult;

      if (_isEditing) {
        /// ================= UPDATE =================
        wargaId = widget.wargaId!;

        await FirebaseFirestore.instance
            .collection('warga')
            .doc(wargaId)
            .update(wargaData);

        /// 🔥 update user login juga
        accountResult = await upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          noHpPenghuni: hp,
          role: _selectedRole,
          newRawPassword: null,
        );

        if (password != null) {
          resetResult = await AuthService().adminResetResidentPassword(
            wargaId: wargaId,
            newPassword: password,
          );
        }

        await SekretarisSyncService().syncWarga(
          rumah: rumah,
          nama: nama,
          noHpPenghuni: hp,
          status: (_selectedStatus ?? 'Dihuni'),
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
        accountResult = await upsertUserLogin(
          wargaId: wargaId,
          nama: nama,
          rumah: rumah,
          noHpPenghuni: hp,
          role: _selectedRole,
          newRawPassword: password,
        );

        await SekretarisSyncService().syncWarga(
          rumah: rumah,
          nama: nama,
          noHpPenghuni: hp,
          status: (_selectedStatus ?? 'Dihuni'),
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
      final credentialEmail = resetResult?.authEmail.isNotEmpty == true
          ? resetResult!.authEmail
          : accountResult.authEmail;
      final credentialPassword = resetResult?.password.isNotEmpty == true
          ? resetResult!.password
          : accountResult.rawPassword;

      bool whatsappSent = false;
      String? whatsappError;

      if (hp.isNotEmpty && credentialPassword != null) {
        final message =
            '''
Halo Bapak/Ibu $nama

${_isEditing ? 'Password akun Anda telah direset oleh pengurus.' : 'Akun Anda telah dibuat.'}
Untuk mengetahui Informasi pembayaran iuran Anda dan
Keadaan keuangan di Perumahan kita tercinta ini.

  Login:
Email: $credentialEmail
Password: $credentialPassword

Silakan login dan segera ganti password.
Jika ada pertanyaan jangan sungkan untuk menghubungi kami baik di Group atau DM langsung.

Terima kasih
Pengurus Perumahan Mulia Land Patria. 
''';

        try {
          await WhatsappService.sendMessage(phone: hp, message: message);
          whatsappSent = true;
        } catch (e) {
          whatsappError = e.toString();
          debugPrint('Gagal kirim WA: $e');
        }
      }

      if (credentialPassword != null) {
        await SessionService.saveTemporaryResidentCredential(
          wargaId: wargaId,
          nama: nama,
          authEmail: credentialEmail,
          password: credentialPassword,
          phone: hp,
          whatsappSent: whatsappSent,
          whatsappError: whatsappError,
        );
      }

      /// =========================================
      /// 🔔 NOTIFIKASI
      /// =========================================
      if (mounted) {
        if (credentialPassword != null) {
          await _showCredentialDialog(
            nama: nama,
            wargaId: wargaId,
            authEmail: credentialEmail,
            password: credentialPassword,
            phone: hp,
            whatsappSent: whatsappSent,
            whatsappError: whatsappError,
          );
        }
        if (!mounted) return;
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
        if (!mounted) return;
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

  Future<void> _showCredentialDialog({
    required String nama,
    required String wargaId,
    required String authEmail,
    required String password,
    required String phone,
    required bool whatsappSent,
    String? whatsappError,
  }) async {
    final waStatus = phone.isEmpty
        ? 'Nomor HP kosong. Kredensial disimpan sementara di perangkat ini.'
        : whatsappSent
        ? 'Kredensial juga sudah dikirim ke WhatsApp $phone.'
        : 'WhatsApp gagal dikirim. Kredensial disimpan sementara di perangkat ini.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_isEditing ? 'Password Baru Warga' : 'Kredensial Warga'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama: $nama'),
              Text('Warga ID: $wargaId'),
              const SizedBox(height: 12),
              SelectableText('Email: $authEmail'),
              const SizedBox(height: 8),
              SelectableText('Password: $password'),
              const SizedBox(height: 12),
              Text(waStatus),
              if ((whatsappError ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Detail WA: $whatsappError',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'Nama: $nama\nWarga ID: $wargaId\nEmail: $authEmail\nPassword: $password',
                  ),
                );
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Kredensial berhasil disalin')),
                );
              },
              child: const Text('Salin'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
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
                    final normalizedNewValue = (newValue ?? '').toLowerCase();
                    final normalizedPreviousStatus = (previousStatus ?? '')
                        .toLowerCase();

                    if (normalizedNewValue == 'kosong' &&
                        normalizedPreviousStatus != 'kosong') {
                      _isIuranAktif = false;
                    } else if (normalizedNewValue != 'kosong' &&
                        normalizedPreviousStatus == 'kosong' &&
                        !_isIuranAktif) {
                      _isIuranAktif = true;
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
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Iuran Aktif'),
                subtitle: Text(
                  (_selectedStatus ?? '').toLowerCase() == 'kosong'
                      ? 'Default nonaktif untuk rumah kosong. Nyalakan bila rumah kosong ini tetap dikenakan iuran.'
                      : 'Matikan bila warga tertentu sementara tidak perlu digenerate iuran.',
                ),
                value: _isIuranAktif,
                onChanged: (value) {
                  setState(() {
                    _isIuranAktif = value;
                  });
                },
              ),
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
                      ? 'Kosongkan jika tidak ingin mengubah password Firebase Auth'
                      : 'Kosongkan untuk password random otomatis Firebase Auth',
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
