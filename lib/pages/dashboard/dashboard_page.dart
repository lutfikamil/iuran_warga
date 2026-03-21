import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String get _role => (SessionService.getRole() ?? '').toLowerCase();

  bool get _showSekertarisMenu =>
      _role == 'admin' || _role == 'ketua' || _role == 'sekertaris';

  bool get _showMusolahMenu =>
      _role == 'admin' ||
      _role == 'ketua' ||
      _role == 'bendahara' ||
      _role == 'pengurus_musolah';

  /// =========================
  /// MENU LIST
  /// =========================
  List<Map<String, dynamic>> get menus {
    final items = [
      _menu("Profile", Icons.person, AppRoutes.profile),
      _menu("Laporan Global", Icons.book, AppRoutes.laporanGlobal),
      _menu("Data Warga", Icons.people, AppRoutes.warga, Colors.blue),
      _menu(
        "Pemasukan Iuran",
        Icons.payments,
        AppRoutes.pembayaran,
        Colors.green,
      ),
      _menu(
        "Pemasukan Umum",
        Icons.trending_down,
        AppRoutes.pemasukan,
        Colors.green,
      ),
      _menu(
        "Pengeluaran",
        Icons.trending_up,
        AppRoutes.pengeluaran,
        Colors.red,
      ),
      _menu("Laporan", Icons.bar_chart, AppRoutes.laporan),
      _menu("Pengaturan", Icons.settings, AppRoutes.settings),
    ];

    if (_showSekertarisMenu) {
      items.insert(
        7,
        _menu(
          "Data Sekertaris",
          Icons.assignment,
          AppRoutes.sekertarisData,
          Colors.teal,
        ),
      );
    }

    if (_showMusolahMenu) {
      items.add(
        _menu(
          "Keuangan Musolah",
          Icons.mosque,
          AppRoutes.keuanganMusolah,
          Colors.green[700],
        ),
      );
    }

    return items;
  }

  Map<String, dynamic> _menu(
    String title,
    IconData icon,
    String route, [
    Color? color,
  ]) {
    return {
      "title": title,
      "icon": icon,
      "route": route,
      "color": color ?? Colors.orange,
    };
  }

  /// =========================
  /// MENU CARD
  /// =========================
  Widget _menuCard(BuildContext context, Map<String, dynamic> menu) {
    final color = menu["color"] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, menu["route"]),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(menu["icon"], size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                menu["title"],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================
  /// LOGOUT
  /// =========================
  Future<void> logout(BuildContext context) async {
    await SessionService.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  /// =========================
  /// BUILD
  /// =========================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 2;
    if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Iuran"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          itemCount: menus.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 25,
            mainAxisSpacing: 25,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            return _menuCard(context, menus[index]);
          },
        ),
      ),
    );
  }
}
