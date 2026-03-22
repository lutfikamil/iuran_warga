import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class LoginDevPage extends StatefulWidget {
  const LoginDevPage({super.key});

  @override
  State<LoginDevPage> createState() => _LoginDevPageState();
}

class _LoginDevPageState extends State<LoginDevPage> {
  final TextEditingController identifierController = TextEditingController(
    text: ("admin@perum.com"),
  );
  final TextEditingController passwordController = TextEditingController(
    text: ("123456"),
  );

  bool loading = false;

  // ✅ TAMBAHAN
  bool _obscurePassword = true;

  Future<void> _showForgotPasswordDialog() async {
    final resetIdentifierController = TextEditingController(
      text: identifierController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitReset() async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              setDialogState(() => isSubmitting = true);
              try {
                final result = await AuthService().resetPasswordForResident(
                  resetIdentifierController.text.trim(),
                );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                final message = result.sentToWhatsapp
                    ? 'Password sementara sudah dikirim ke WhatsApp ${result.maskedPhone}. Silakan login lalu segera ganti password.'
                    : 'Password sementara berhasil dibuat, tetapi pengiriman WhatsApp gagal. Password sementara Anda: ${result.temporaryPassword}';
                if (!mounted) return;
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(message)));
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Lupa Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan email, nomor HP, atau nomor rumah yang terdaftar. Password sementara akan dikirim ke WhatsApp yang tersimpan pada akun.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetIdentifierController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Email / No HP / No Rumah',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Identifier wajib diisi';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!isSubmitting) {
                          submitReset();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitReset,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset Password'),
                ),
              ],
            );
          },
        );
      },
    );

    resetIdentifierController.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    try {
      final loginResult = await AuthService().loginFlexible(
        identifierController.text.trim(),
        passwordController.text.trim(),
      );

      await SessionService.saveLogin(
        role: loginResult.role,
        identifier: loginResult.identifier,
        isAdmin: loginResult.isAdmin,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboard,
        arguments: loginResult.role,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          child: Card(
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo_perumahan.png', height: 150),

                  const SizedBox(height: 10),
                  const Text(
                    "Login Sistem Iuran\nMULIA LAND",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: identifierController,
                    decoration: const InputDecoration(
                      labelText: "Email / No HP / No Rumah",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ PASSWORD FIELD + EYE
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),

                      // 👁️ ICON EYE
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : _showForgotPasswordDialog,
                      child: const Text('Lupa password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
