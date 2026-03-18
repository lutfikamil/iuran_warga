import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/log_service.dart';

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
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
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

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password berhasil diganti")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengganti password: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Ganti Password",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: "Password Saat Ini",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),

                // 👁️
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return "Password saat ini wajib diisi";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: "Password Baru",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),

                // 👁️
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return "Password baru wajib diisi";
                }
                if (v.length < 6) {
                  return "Minimal 6 karakter";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: "Konfirmasi Password Baru",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_reset),

                // 👁️
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return "Konfirmasi password wajib diisi";
                }

                if (v != _newPasswordController.text) {
                  return "Password tidak sama";
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Simpan Password"),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
