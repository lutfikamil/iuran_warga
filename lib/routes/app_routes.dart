import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../pages/laporan/laporan_page.dart';
import '../pages/login/login_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/warga/warga_page.dart';
import '../pages/warga/warga_keluar_page.dart';
import '../pages/pembayaran/pembayaran_page.dart';
import '../pages/laporan/laporan_global_page.dart';
import '../pages/pengeluaran/pengeluaran_page.dart';
import '../pages/pengeluaran/add_pengeluaran_page.dart';
import '../pages/pemasukan/pemasukan_page.dart';
import '../pages/pemasukan/add_pemasukan_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/sekretaris/sekretaris_data_page.dart';
import '../pages/keuangan_musolah/keuangan_musolah_page.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../pages/login/login_dev_page.dart';

final AuthService authService = AuthService();

class AppRoutes {
  static const login = "/";
  static const loginDev = "/";
  static const dashboard = "/dashboard";
  static const warga = "/warga";
  static const pembayaran = "/pembayaran";
  static const wargaKeluar = "/warga_keluar";
  static const pengeluaran = "/pengeluaran";
  static const addPengeluaran = "/add_pengeluaran";
  static const pemasukan = "/pemasukan";
  static const addPemasukan = "/add_pemasukan";
  static const laporan = "/laporan";
  static const laporanGlobal = "/laporan_global";
  static const settings = "/settings";
  static const profile = "/profile";
  static const sekretarisData = "/sekretaris_data";
  static const keuanganMusolah = "/keuangan_musolah";
  static const unauthorized = "/unauthorized";
  static Widget _buildGuardedRoute({
    required Widget page,
    required List<UserRole> allowedRoles,
  }) {
    return Builder(
      builder: (context) {
        final isLoggedIn = SessionService.isLogin();
        final savedRole = SessionService.getRole();

        if (!isLoggedIn || savedRole == null || savedRole.trim().isEmpty) {
          authService.setCurrentUserRole(UserRole.unauthenticated);
          return const LoginPage();
        }

        authService.restoreRoleFromSession(savedRole);

        if (authService.hasAnyRole(allowedRoles)) {
          return page;
        }

        return const UnauthorizedPage();
      },
    );
  }

  static Map<String, WidgetBuilder> routes = {
    login: (_) => kDebugMode ? const LoginDevPage() : const LoginPage(),
    dashboard: (_) =>
        _buildGuardedRoute(page: const DashboardPage(), allowedRoles: []),

    warga: (_) => _buildGuardedRoute(page: const WargaPage(), allowedRoles: []),
    pembayaran: (_) => _buildGuardedRoute(
      page: const PembayaranPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara, UserRole.petugas],
    ),
    wargaKeluar: (_) => _buildGuardedRoute(
      page: const WargaKeluarPage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.bendahara,
        UserRole.sekretaris,
        UserRole.petugas,
      ],
    ),
    pengeluaran: (_) => _buildGuardedRoute(
      page: const PengeluaranPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara],
    ),
    addPengeluaran: (_) => _buildGuardedRoute(
      page: const AddPengeluaranPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara],
    ),
    pemasukan: (_) => _buildGuardedRoute(
      page: const PemasukanPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara],
    ),
    addPemasukan: (_) => _buildGuardedRoute(
      page: const AddPemasukanPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara],
    ),
    laporan: (_) =>
        _buildGuardedRoute(page: const LaporanPage(), allowedRoles: []),
    laporanGlobal: (_) =>
        _buildGuardedRoute(page: const LaporanGlobalPage(), allowedRoles: []),
    settings: (_) => _buildGuardedRoute(
      page: const SettingsPage(),
      allowedRoles: [UserRole.admin, UserRole.sekretaris],
    ),
    profile: (_) =>
        _buildGuardedRoute(page: const ProfilePage(), allowedRoles: []),
    sekretarisData: (_) => _buildGuardedRoute(
      page: const SekretarisDataPage(),
      allowedRoles: [UserRole.admin, UserRole.ketua, UserRole.sekretaris],
    ),
    keuanganMusolah: (_) =>
        _buildGuardedRoute(page: const KeuanganMusolahPage(), allowedRoles: []),
    unauthorized: (_) => const UnauthorizedPage(), // Tambahkan rute ini juga
  };
}

// --- Halaman Placeholder untuk Akses Ditolak ---
class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akses Ditolak')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Anda tidak memiliki izin untuk mengakses halaman ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            // Tambahkan tombol untuk kembali ke dashboard atau logout
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
            //   },
            //   child: const Text('Kembali ke Dashboard'),
            // ),
          ],
        ),
      ),
    );
  }
}
