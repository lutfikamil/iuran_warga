import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController(
    text: 'admin@mulialand.com',
  );
  final TextEditingController passwordController = TextEditingController(
    text: '123456',
  );

  bool loading = false;

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    try {
      final role = await AuthService().loginFlexible(
        identifierController.text.trim(),
        passwordController.text.trim(),
      );
      await SessionService.saveLogin(role);
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboard,
        arguments: role,
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
                  const Text(
                    "Login Sistem Iuran",
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

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

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
