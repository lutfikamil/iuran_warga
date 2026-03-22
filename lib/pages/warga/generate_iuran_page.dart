import 'package:flutter/material.dart';
import '../../services/iuran_service.dart';
import '../../utils/bulan_util.dart';

class GeneratePage {
  /// =========================
  /// GENERATE IURAN BULANAN
  /// =========================
  static Future<void> generateIuranDialog(BuildContext context) async {
    String? selectedBulan;
    int selectedTahun = DateTime.now().year;
    final waktuUtil = ListBulanIuran();

    final result = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Generate Iuran"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBulan,
                    hint: const Text("Pilih Bulan"),
                    items: waktuUtil.bulanList.map((bulan) {
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
                    initialValue: selectedTahun,
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

    await IuranService().generateIuran(result["bulan"], result["tahun"]);

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Iuran berhasil dibuat")));
  }

  /// =========================
  /// GENERATE IURAN SETAHUN
  /// =========================
  static Future<void> generateIuranSetahunDialog(BuildContext context) async {
    int selectedTahun = DateTime.now().year;

    final tahun = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Generate Iuran 1 Tahun"),
          content: DropdownButtonFormField<int>(
            initialValue: selectedTahun,
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

    await IuranService().generateIuranSetahun(tahun);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Iuran 1 tahun ($tahun) berhasil dibuat")),
    );
  }
}
