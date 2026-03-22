import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'routes/app_routes.dart';
import 'services/firestore_offline_service.dart';
import 'services/auth_service.dart';
import 'services/session_service.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirestoreOfflineService.configure();
  await initializeDateFormatting('id_ID', null);
  await SessionService.init();
  final isLogin = SessionService.isLogin();
  AuthService().restoreRoleFromSession(SessionService.getRole());

  runApp(MyApp(isLogin: isLogin));
}

class MyApp extends StatelessWidget {
  final bool isLogin;

  const MyApp({super.key, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iuran Warga MuliaLand',

      debugShowCheckedModeBanner: false,

      initialRoute: isLogin ? AppRoutes.dashboard : AppRoutes.login,

      routes: AppRoutes.routes,
    );
  }
}
