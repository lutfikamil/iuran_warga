import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/dashboard/dashboard_stat.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  /// =========================
  /// MENU LIST
  /// =========================
  List<Map<String, dynamic>> get menus => [
    {"title": "Profile", "icon": Icons.person, "route": AppRoutes.profile},
    {
      "title": "Data Warga",
      "icon": Icons.people,
      "route": AppRoutes.warga,
      "color": Colors.green,
    },
    {
      "title": "Pembayaran",
      "icon": Icons.payments,
      "route": AppRoutes.pembayaran,
    },
    {
      "title": "Pemasukan Umum",
      "icon": Icons.trending_down,
      "route": AppRoutes.pemasukan,
      "color": Colors.green,
    },
    {
      "title": "Pengeluaran",
      "icon": Icons.trending_up,
      "route": AppRoutes.pengeluaran,
      "color": Colors.red,
    },
    {"title": "Laporan", "icon": Icons.bar_chart, "route": AppRoutes.laporan},
    {
      "title": "Laporan Global",
      "icon": Icons.book,
      "route": AppRoutes.laporanGlobal,
    },
    {
      "title": "Pengaturan",
      "icon": Icons.settings,
      "route": AppRoutes.settings,
    },
  ];

  /// =========================
  /// MENU CARD
  /// =========================
  Widget menuCard(BuildContext context, Map<String, dynamic> menu) {
    final color = menu["color"]?? Colors.orange;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, menu["route"]),
      child: Card(
        elevation: 5,
        child: SizedBox(
          width: 140,
          height: 95,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(menu["icon"], size: 32, color: color),
              ),
              const SizedBox(height: 10),
              Text(menu["title"]),
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
    final dashboardService = DashboardService();

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
      body: FutureBuilder(
        future: Future.wait([
          dashboardService.totalWarga(),
          dashboardService.totalKas(),
          dashboardService.wargaBelumBayar(),
          dashboardService.totalTunggakan(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState!= ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalWarga = snapshot.data?[0]?? 0;
          final totalKas = snapshot.data?[1]?? 0;
          final belumBayar = snapshot.data?[2]?? 0;
          final tunggakan = snapshot.data?[3]?? 0;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 2;

                    if (constraints.maxWidth > 900) {
                      crossAxisCount = 4; // desktop
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 3; // tablet
                    }

                    double itemWidth =
                        (constraints.maxWidth - (18 * (crossAxisCount - 1))) /
                        crossAxisCount;

                    return Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: DashboardStat(
                            title: "Total Warga",
                            value: totalWarga.toString(),
                            icon: Icons.people,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DashboardStat(
                            title: "Total Kas",
                            value: "Rp $totalKas",
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DashboardStat(
                            title: "Belum Bayar",
                            value: belumBayar.toString(),
                            icon: Icons.warning,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DashboardStat(
                            title: "Total Tunggakan",
                            value: "Rp $tunggakan",
                            icon: Icons.money_off,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),

                const Text(
                  "Menu",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: menus
                     .map((menu) => menuCard(context, menu))
                     .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}