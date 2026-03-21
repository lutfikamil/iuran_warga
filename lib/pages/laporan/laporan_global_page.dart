import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/dashboard/dashboard_stat.dart';

class LaporanGlobalPage extends StatelessWidget {
  const LaporanGlobalPage({super.key});

  /// =========================
  /// MENU CARD
  /// =========================
  Widget menuCard(BuildContext context, Map<String, dynamic> menu) {
    final color = menu["color"] ?? Colors.orange;
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
  /// BUILD
  /// =========================
  @override
  Widget build(BuildContext context) {
    final dashboardService = DashboardService();

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard Laporan Global")),
      body: FutureBuilder(
        future: Future.wait([
          dashboardService.totalWargaAktif(),
          dashboardService.totalSaldoKasFormatted(),
          dashboardService.jumlahWargaMenunggak(),
          dashboardService.totalNominalTunggakanFormatted(),
          dashboardService.getStatistikKetaatan(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Data Laporan Global gagal dimuat.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final totalWarga = snapshot.data?[0] ?? 0;
          final totalKas = (snapshot.data?[1] as String?) ?? 'Rp 0';

          final belumBayar = snapshot.data?[2] ?? 0;
          final tunggakan = (snapshot.data?[3] as String?) ?? 'Rp 0';
          final data = snapshot.data;

          final ketaatanData = (data != null && data.length > 4)
              ? data[4] as Map<String, dynamic>
              : {};

          final persenKetaatan = (ketaatanData["persen"] ?? 0).toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ketaatan Warga: ${persenKetaatan.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                            value: totalKas,
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
                            value: tunggakan,
                            icon: Icons.money_off,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
