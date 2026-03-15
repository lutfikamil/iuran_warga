import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/tagihan_service.dart';
import '../../widgets/dashboard/dashboard_stat.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Widget menuCard(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Card(
        elevation: 5,
        child: SizedBox(
          width: 200,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 10),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    await SessionService.logout();

    if (!context.mounted) return;

    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Iuran"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Generate Tagihan"),
                  content: const Text(
                    "Buat tagihan bulan ini untuk semua warga?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Batal"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Ya"),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              final now = DateTime.now();
              final bulan =
                  "${now.year}-${now.month.toString().padLeft(2, '0')}";

              await TagihanService().generateTagihan(bulan);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tagihan berhasil dibuat")),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          DashboardService().totalWarga(),
          DashboardService().totalKas(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalWarga = snapshot.data![0];
          final totalKas = snapshot.data![1];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// STATISTIK
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    DashboardStat(
                      title: "Total Warga",
                      value: totalWarga.toString(),
                      icon: Icons.people,
                    ),

                    DashboardStat(
                      title: "Total Kas",
                      value: "Rp $totalKas",
                      icon: Icons.account_balance_wallet,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                /// MENU
                const Text(
                  "Menu",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    menuCard(
                      context,
                      "Data Warga",
                      Icons.people,
                      AppRoutes.warga,
                    ),

                    menuCard(
                      context,
                      "Pembayaran",
                      Icons.payments,
                      AppRoutes.pembayaran,
                    ),

                    menuCard(
                      context,
                      "Pengeluaran",
                      Icons.bar_chart,
                      AppRoutes.pengeluaran,
                    ),

                    menuCard(
                      context,
                      "Laporan",
                      Icons.bar_chart,
                      AppRoutes.laporan,
                    ),

                    menuCard(
                      context,
                      "LaporanGlobal",
                      Icons.bar_chart,
                      AppRoutes.laporanGlobal,
                    ),

                    menuCard(
                      context,
                      "Daftar Iuran Warga",
                      Icons.money,
                      AppRoutes.daftarIuran,
                    ),

                    menuCard(
                      context,
                      "Pengaturan",
                      Icons.money,
                      AppRoutes.settings,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
