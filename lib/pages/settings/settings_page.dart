import 'package:flutter/material.dart';

import '../../services/log_service.dart';
import '../../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();

  final TextEditingController _iuranController = TextEditingController();
  final TextEditingController _whatsappServerController =
      TextEditingController();
  final TextEditingController _whatsappTokenController =
      TextEditingController();
  final TextEditingController _whatsappPhoneController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final amount = await _settingsService.getIuranAmount();
    final whatsappSettings = await _settingsService.getWhatsappSettings();

    _iuranController.text = amount.toInt().toString();
    _whatsappServerController.text = whatsappSettings.apiServer;
    _whatsappTokenController.text = whatsappSettings.apiToken;
    _whatsappPhoneController.text = whatsappSettings.senderPhone;

    setState(() {
      _loading = false;
    });
  }

  Future<void> saveSettings() async {
    final value = double.tryParse(_iuranController.text);
    final apiServer = _whatsappServerController.text.trim();
    final apiToken = _whatsappTokenController.text.trim();
    final senderPhone = _whatsappPhoneController.text.trim();

    if (value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nominal tidak valid')));
      return;
    }

    final apiUri = Uri.tryParse(apiServer);

    if (apiServer.isNotEmpty &&
        (apiUri == null || !apiUri.hasScheme || !apiUri.hasAuthority)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server API WhatsApp tidak valid')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    await _settingsService.updateIuranAmount(value);
    await _settingsService.updateWhatsappSettings(
      WhatsappSettings(
        apiServer: apiServer,
        apiToken: apiToken,
        senderPhone: senderPhone,
      ),
    );

    await LogService().logEvent(
      action: 'update_setting_iuran',
      target: 'settings/iuran',
      detail: 'Ubah nominal iuran menjadi Rp ${value.toStringAsFixed(0)}',
    );
    await LogService().logEvent(
      action: 'update_setting_whatsapp',
      target: 'settings/whatsapp',
      detail: 'Perbarui konfigurasi WhatsApp gateway',
    );

    setState(() {
      _saving = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Setting berhasil disimpan')),
    );
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
    _whatsappServerController.dispose();
    _whatsappTokenController.dispose();
    _whatsappPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildCard(
              title: 'Besaran Iuran Bulanan',
              child: TextField(
                controller: _iuranController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Iuran',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            buildCard(
              title: 'Konfigurasi WhatsApp Gateway',
              child: Column(
                children: [
                  TextField(
                    controller: _whatsappServerController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server API',
                      hintText: 'https://api.fonnte.com/send',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _whatsappTokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token API',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _whatsappPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP Device / Sender',
                      hintText: '08xxxxxxxxxx',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Isi nomor device/sender jika gateway Anda membutuhkannya. Token tidak ditampilkan di log aktivitas.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
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
                    : const Text('Simpan Pengaturan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
