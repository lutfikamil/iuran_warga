import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/log_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();

  final TextEditingController _iuranController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final amount = await _settingsService.getIuranAmount();

    _iuranController.text = amount.toInt().toString();

    setState(() {
      _loading = false;
    });
  }

  Future<void> saveSettings() async {
    final value = double.tryParse(_iuranController.text);

    if (value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nominal tidak valid")));
      return;
    }

    setState(() {
      _saving = true;
    });

    await _settingsService.updateIuranAmount(value);
    await LogService().logEvent(
      action: 'update_setting_iuran',
      target: 'settings/iuran',
      detail: 'Ubah nominal iuran menjadi Rp ${value.toStringAsFixed(0)}',
    );

    setState(() {
      _saving = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Setting berhasil disimpan")));
  }

  Widget buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _iuranController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// SETTING IURAN
            buildCard(
              title: "Besaran Iuran Bulanan",
              child: TextField(
                controller: _iuranController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nominal Iuran",
                  prefixText: "Rp ",
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : saveSettings,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Simpan Pengaturan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
