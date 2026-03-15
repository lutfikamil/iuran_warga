import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/log_service.dart';
import '../../services/session_service.dart';
import 'logs_page.dart'; // Asumsi LogsPage ini akan direfactor menjadi widget yang lebih kecil atau diimpor untuk bagian log saja.

// Widget baru untuk mengganti password (tetap terpisah, tapi nanti dipanggil dari bottom sheet)
class PasswordChangeForm extends StatefulWidget {
  final String identifier;
  final String role;
  final bool isAdmin;

  const PasswordChangeForm({
    super.key,
    required this.identifier,
    required this.role,
    required this.isAdmin,
  });

  @override
  State<PasswordChangeForm> createState() => _PasswordChangeFormState();
}

class _PasswordChangeFormState extends State<PasswordChangeForm> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _changingPassword = false;

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _changingPassword = true;
    });

    try {
      await AuthService().changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        isAdmin: widget.isAdmin,
        identifier: widget.identifier,
      );

      await LogService().logEvent(
        action: 'change_password',
        target: widget.isAdmin ? 'firebase_auth/admin' : 'users',
        detail:
            'Ubah password oleh role ${widget.role} dengan identifier ${widget.identifier}',
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();

      if (!mounted) return;
      // Tutup bottom sheet setelah berhasil
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengganti password: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(
          context,
        ).viewInsets.bottom, // Menyesuaikan dengan keyboard
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Agar column tidak memenuhi tinggi
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ganti Password',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password saat ini',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Password saat ini wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Password baru wajib diisi';
                if (v.length < 6) {
                  return 'Password baru minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmNewPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi password baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_reset),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Konfirmasi password wajib diisi';
                }
                if (value.trim() != _newPasswordController.text.trim()) {
                  return 'Konfirmasi password tidak sama';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _changingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _changingPassword
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simpan Password Baru',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Widget baru untuk menampilkan log
class LogsWidget extends StatelessWidget {
  final bool isAdmin;

  const LogsWidget({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            isAdmin
                ? 'Logs Aktivitas Admin'
                : 'Logs hanya dapat dilihat admin.',
            style: TextStyle(
              fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
              fontSize: 18,
            ),
          ),
        ),
        Expanded(
          child: isAdmin
              ? const LogsPage()
              : const Center(
                  // Tambahkan center agar tampilan lebih rapi saat tidak ada log
                  child: Text(
                    'Tidak ada aktivitas log yang dapat ditampilkan.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _role = '-';
  String _identifier = '-';
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    final role = await SessionService.getRole();
    final identifier = await SessionService.getIdentifier();
    final isAdmin = await SessionService.isAdminLogin();

    if (!mounted) return;

    setState(() {
      _role = role ?? '-';
      _identifier = identifier ?? '-';
      _isAdmin = isAdmin;
      _loading = false;
    });
  }

  // Fungsi untuk menampilkan bottom sheet ganti password
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Penting agar keyboard tidak menutupi input
      builder: (BuildContext context) {
        return PasswordChangeForm(
          identifier: _identifier,
          role: _role,
          isAdmin: _isAdmin,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Role pengguna'),
              subtitle: Text(_role),
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.badge)),
              title: const Text('Identifier login'),
              subtitle: Text(_identifier),
            ),
          ),
          // Tambahkan tombol untuk memunculkan bottom sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _showChangePasswordSheet,
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Ganti Password'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), // Ukuran tombol
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Menggunakan widget LogsWidget yang baru
          Expanded(child: LogsWidget(isAdmin: _isAdmin)),
        ],
      ),
    );
  }
}
