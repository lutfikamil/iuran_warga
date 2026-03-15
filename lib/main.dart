import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_routes.dart';
import 'services/session_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  bool isLogin = await SessionService.isLogin();

  runApp(MyApp(isLogin: isLogin));
}

class MyApp extends StatelessWidget {
  final bool isLogin;

  const MyApp({super.key, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Iuran',

      debugShowCheckedModeBanner: false,

      initialRoute: isLogin ? AppRoutes.dashboard : AppRoutes.login,

      routes: AppRoutes.routes,
    );
  }
}
