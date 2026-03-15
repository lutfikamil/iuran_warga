import 'package:flutter/material.dart';
import '../pages/laporan/laporan_page.dart';
import '../pages/login/login_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/warga/warga_page.dart';
import '../pages/pembayaran/pembayaran_page.dart';
import '../pages/laporan/laporan_global_page.dart';
import '../pages/pembayaran/daftar_iuran_page.dart';
import '../pages/pengeluaran/pengeluaran_page.dart';
import '../pages/pengeluaran/add_pengeluaran_page.dart';
import '../pages/settings/settings_page.dart';

class AppRoutes {
  static const login = "/";
  static const dashboard = "/dashboard";
  static const warga = "/warga";
  static const pembayaran = "/pembayaran";
  static const pengeluaran = "/pengeluaran";
  static const addPengeluaran = "/add_pengeluaran";
  static const laporan = "/laporan";
  static const laporanGlobal = "/laporan_global";
  static const daftarIuran = "/daftar_iuran";
  static const settings = "/settings";

  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginPage(),
    dashboard: (_) => const DashboardPage(),
    warga: (_) => const WargaPage(),
    pembayaran: (_) => const PembayaranPage(),
    pengeluaran: (_) => const PengeluaranPage(),
    addPengeluaran: (_) => const AddPengeluaranPage(),
    laporan: (_) => const LaporanPage(),
    laporanGlobal: (_) => const LaporanGlobalPage(),
    daftarIuran: (_) => const DaftarIuranPage(),
    settings: (_) => const SettingPage(),
  };
}
