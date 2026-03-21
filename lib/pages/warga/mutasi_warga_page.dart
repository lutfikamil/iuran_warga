import 'package:flutter/material.dart';

import '../../services/warga_lifecycle_service.dart';

class MutasiWargaPage extends StatefulWidget {
  const MutasiWargaPage({
    super.key,
    required this.wargaId,
    required this.nama,
    required this.rumah,
  });

  final String wargaId;
  final String nama;
  final String rumah;

  @override
  State<MutasiWargaPage> createState() => _MutasiWargaPageState();
}

class _MutasiWargaPageState extends State<MutasiWargaPage> {
  final _rumahBaruController = TextEditingController();
  final _namaPemilikBaruController = TextEditingController();
  final _hpPemilikBaruController = TextEditingController();
  final WargaLifecycleService _lifecycleService = WargaLifecycleService();

  bool _loadingPindah = false;
  bool _loadingKeluar = false;
  bool _loadingPemilik = false;

  @override
  void initState() {
    super.initState();
    _rumahBaruController.text = widget.rumah;
  }

  @override
  void dispose() {
    _rumahBaruController.dispose();
    _namaPemilikBaruController.dispose();
    _hpPemilikBaruController.dispose();
    super.dispose();
  }

  Future<void> _handlePindahRumah() async {
    setState(() => _loadingPindah = true);
    try {
      await _lifecycleService.pindahRumah(
        wargaId: widget.wargaId,
        rumahBaru: _rumahBaruController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mutasi pindah rumah berhasil disimpan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal pindah rumah: $e')));
    } finally {
      if (mounted) {
        setState(() => _loadingPindah = false);
      }
    }
  }

  Future<void> _handleKeluar() async {
    setState(() => _loadingKeluar = true);
    try {
      await _lifecycleService.arsipkanWargaKeluar(
        wargaId: widget.wargaId,
        statusKeluar: 'huni ${widget.rumah}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warga berhasil dipindah ke arsip keluar.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengarsipkan warga: $e')));
    } finally {
      if (mounted) {
        setState(() => _loadingKeluar = false);
      }
    }
  }

  Future<void> _handleGantiPemilik() async {
    final namaBaru = _namaPemilikBaruController.text.trim();
    if (namaBaru.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pemilik baru wajib diisi.')),
      );
      return;
    }

    setState(() => _loadingPemilik = true);
    try {
      await _lifecycleService.gantiPemilikRumah(
        wargaIdLama: widget.wargaId,
        namaBaru: namaBaru,
        hpBaru: _hpPemilikBaruController.text,
        rumah: widget.rumah,
        statusHunianBaru: 'Kosong',
        iuranAktif: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pergantian pemilik berhasil disimpan.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ganti pemilik: $e')));
    } finally {
      if (mounted) {
        setState(() => _loadingPemilik = false);
      }
    }
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi Warga')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.nama,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Rumah saat ini: ${widget.rumah}'),
                  const SizedBox(height: 4),
                  const Text(
                    'Nama hanya boleh dikoreksi untuk typo. Jika orangnya berubah, gunakan mutasi atau ganti pemilik.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Pindah Rumah',
            description:
                'Gunakan jika orang yang sama pindah rumah. WargaId tetap, hanya rumah yang berubah.',
            child: Column(
              children: [
                TextField(
                  controller: _rumahBaruController,
                  decoration: const InputDecoration(
                    labelText: 'Rumah baru',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loadingPindah ? null : _handlePindahRumah,
                    child: _loadingPindah
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Mutasi Pindah Rumah'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Keluar Perumahan',
            description:
                'Gunakan jika warga keluar dari perumahan. Data aktif diarsipkan ke warga keluar dengan status huni rumah terakhir.',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _loadingKeluar ? null : _handleKeluar,
                child: _loadingKeluar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Arsipkan ke Warga Keluar'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Ganti Pemilik Rumah',
            description:
                'Gunakan jika pemilik berubah. Data pemilik lama akan diarsipkan dengan status ex rumah ini, lalu dibuat wargaId baru untuk pemilik baru.',
            child: Column(
              children: [
                TextField(
                  controller: _namaPemilikBaruController,
                  decoration: const InputDecoration(
                    labelText: 'Nama pemilik baru',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hpPemilikBaruController,
                  decoration: const InputDecoration(
                    labelText: 'No HP pemilik baru',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loadingPemilik ? null : _handleGantiPemilik,
                    child: _loadingPemilik
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Pergantian Pemilik'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
