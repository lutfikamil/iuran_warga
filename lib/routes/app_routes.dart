import 'package:flutter/material.dart';
import '../pages/laporan/laporan_page.dart';
import '../pages/login/login_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/warga/warga_page.dart';
import '../pages/pembayaran/pembayaran_page.dart';
import '../pages/laporan/rekap_laporan_page.dart';
import '../pages/pengeluaran/pengeluaran_page.dart';
import '../pages/pengeluaran/add_pengeluaran_page.dart';
import '../pages/pemasukan/pemasukan_page.dart';
import '../pages/pemasukan/add_pemasukan_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/sekertaris/sekertaris_data_page.dart';
import '../pages/keuangan_musolah/keuangan_musolah_page.dart';
import '../services/auth_service.dart';

final AuthService authService = AuthService();

class AppRoutes {
  static const login = "/";
  static const dashboard = "/dashboard";
  static const warga = "/warga";
  static const pembayaran = "/pembayaran";
  static const pengeluaran = "/pengeluaran";
  static const addPengeluaran = "/add_pengeluaran";
  static const pemasukan = "/pemasukan";
  static const addPemasukan = "/add_pemasukan";
  static const laporan = "/laporan";
  static const laporanGlobal = "/laporan_global";
  static const settings = "/settings";
  static const profile = "/profile";
  static const sekertarisData = "/sekertaris_data";
  static const keuanganMusolah = "/keuangan_musolah";
  static const unauthorized = "/unauthorized";
  static Widget _buildGuardedRoute({
    required Widget page,
    required List<UserRole> allowedRoles,
  }) {
    return Builder(
      builder: (context) {
        if (authService.hasAnyRole(allowedRoles)) {
          return page;
        } else {
          return const UnauthorizedPage();
        }
      },
    );
  }

  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginPage(),
    dashboard: (_) => _buildGuardedRoute(
      page: const DashboardPage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.bendahara,
        UserRole.sekertaris,
        UserRole.petugas,
        UserRole.pengurusMusolah,
        UserRole.warga,
      ],
    ),
    warga: (_) => _buildGuardedRoute(
      page: const WargaPage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.sekertaris,
        UserRole.petugas,
      ],
    ),
    pembayaran: (_) => _buildGuardedRoute(
      page: const PembayaranPage(),
      allowedRoles: [UserRole.admin, UserRole.bendahara, UserRole.petugas],
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
    laporan: (_) => _buildGuardedRoute(
      page: const LaporanPage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.bendahara,
        UserRole.sekertaris,
      ],
    ),
    laporanGlobal: (_) => _buildGuardedRoute(
      page: const RekapLaporanPage(),
      allowedRoles: [UserRole.admin, UserRole.ketua],
    ),
    //daftarIuran: (_) => _buildGuardedRoute(
    //  page: const DaftarIuranPage(),
    //  allowedRoles: [
    //    UserRole.admin,
    //    UserRole.bendahara,
    //    UserRole.petugas,
    //    UserRole.warga,
    //  ],
    //),
    settings: (_) => _buildGuardedRoute(
      page: const SettingsPage(),
      allowedRoles: [UserRole.admin],
    ),
    profile: (_) => _buildGuardedRoute(
      page: const ProfilePage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.bendahara,
        UserRole.sekertaris,
        UserRole.petugas,
        UserRole.pengurusMusolah,
        UserRole.warga,
      ],
    ),
    sekertarisData: (_) => _buildGuardedRoute(
      page: const SekertarisDataPage(),
      allowedRoles: [UserRole.admin, UserRole.ketua, UserRole.sekertaris],
    ),
    keuanganMusolah: (_) => _buildGuardedRoute(
      page: const KeuanganMusolahPage(),
      allowedRoles: [
        UserRole.admin,
        UserRole.ketua,
        UserRole.bendahara,
        UserRole.pengurusMusolah,
      ],
    ),
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
