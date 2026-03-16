import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/tagihan_service.dart';
import '../../widgets/dashboard/dashboard_stat.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const List<String> bulanList = [
    "Januari",
    "Februari",
    "Maret",
    "April",
    "Mei",
    "Juni",
    "Juli",
    "Agustus",
    "September",
    "Oktober",
    "November",
    "Desember",
  ];

  /// =========================
  /// MENU LIST
  /// =========================
  List<Map<String, dynamic>> get menus => [
    {"title": "Data Warga", "icon": Icons.people, "route": AppRoutes.warga},
    {
      "title": "Pembayaran",
      "icon": Icons.payments,
      "route": AppRoutes.pembayaran,
    },
    {
      "title": "Pemasukan Umum",
      "icon": Icons.trending_up,
      "route": AppRoutes.pemasukan,
    },
    {
      "title": "Pengeluaran",
      "icon": Icons.trending_down,
      "route": AppRoutes.pengeluaran,
    },
    {"title": "Laporan", "icon": Icons.bar_chart, "route": AppRoutes.laporan},
    {
      "title": "Laporan Global",
      "icon": Icons.bar_chart,
      "route": AppRoutes.laporanGlobal,
    },
    {
      "title": "Pengaturan",
      "icon": Icons.settings,
      "route": AppRoutes.settings,
    },
    {"title": "Profile", "icon": Icons.person, "route": AppRoutes.profile},
  ];

  /// =========================
  /// MENU CARD
  /// =========================
  Widget menuCard(BuildContext context, Map<String, dynamic> menu) {
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
              Icon(menu["icon"], size: 32),
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
  /// GENERATE TAGIHAN
  /// =========================
  Future<void> generateTagihanDialog(BuildContext context) async {
    String? selectedBulan;
    int selectedTahun = DateTime.now().year;

    final result = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Generate Tagihan"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedBulan,
                    hint: const Text("Pilih Bulan"),
                    items: bulanList.map((bulan) {
                      return DropdownMenuItem(value: bulan, child: Text(bulan));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBulan = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedTahun,
                    items: List.generate(5, (i) {
                      final tahun = DateTime.now().year + i;
                      return DropdownMenuItem(
                        value: tahun,
                        child: Text(tahun.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedTahun = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      "bulan": selectedBulan,
                      "tahun": selectedTahun,
                    });
                  },
                  child: const Text("Generate"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await TagihanService().generateTagihan(result["bulan"], result["tahun"]);

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Tagihan berhasil dibuat")));
  }

  /// =========================
  /// BUILD
  /// =========================
  @override
  Widget build(BuildContext context) {
    final dashboardService = DashboardService();
    Future<void> generateTagihanSetahunDialog(BuildContext context) async {
      int selectedTahun = DateTime.now().year;

      final tahun = await showDialog<int>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Generate Tagihan 1 Tahun"),
            content: DropdownButtonFormField<int>(
              value: selectedTahun,
              items: List.generate(5, (i) {
                final year = DateTime.now().year + i;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                selectedTahun = value!;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedTahun),
                child: const Text("Generate"),
              ),
            ],
          );
        },
      );

      if (tahun == null) return;

      await TagihanService().generateTagihanSetahun(tahun);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tagihan 1 tahun ($tahun) berhasil dibuat")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Iuran"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Generate 1 Tahun",
            onPressed: () => generateTagihanSetahunDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => generateTagihanDialog(context),
          ),
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
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalWarga = snapshot.data?[0] ?? 0;
          final totalKas = snapshot.data?[1] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// STATISTIK
                Wrap(
                  spacing: 18,
                  runSpacing: 18,
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
