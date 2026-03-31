import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/firestore_offline_service.dart';
import 'services/session_service.dart';
import 'firebase_options_dev.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INIT SESSION (WAJIB kalau pakai versi clean)
  await SessionService.init();

  // 🔥 Firebase init (bisa beda project kalau pakai multi env)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirestoreOfflineService.configure();
  await initializeDateFormatting('id_ID', null);

  await SessionService.init();
  AuthService().restoreRoleFromSession(SessionService.getRole());

  runApp(const MyAppDev());
}

class MyAppDev extends StatelessWidget {
  const MyAppDev({super.key});

  @override
  Widget build(BuildContext context) {
    final isLogin = SessionService.isLogin();

    return MaterialApp(
      title: 'Aplikasi Iuran (DEV)',

      debugShowCheckedModeBanner: true, // 🔥 biar kelihatan DEV

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),

      initialRoute: isLogin ? AppRoutes.dashboard : AppRoutes.login,

      routes: AppRoutes.devRoutes,
    );
  }
}
