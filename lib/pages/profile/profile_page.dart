import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../warga/detail_warga_page.dart';
import 'logs_page.dart';
import 'password_change_form.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _role = '-';
  String _identifier = '-';
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    final role = AuthService.normalizeRole(SessionService.getRole());
    final identifier = SessionService.getIdentifier();
    final isAdmin = SessionService.isAdminLogin();

    if (!mounted) return;

    setState(() {
      _role = role.isEmpty ? '-' : role;
      _identifier = identifier ?? '-';
      _isAdmin = isAdmin;
      _loading = false;
    });
  }

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return PasswordChangeForm(
          identifier: _identifier,
          role: _role,
          isAdmin: _isAdmin,
        );
      },
    );
  }

  /// ==============================
  /// UI UNTUK ADMIN
  /// ==============================
  Widget _buildAdminProfile() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Role pengguna'),
            subtitle: Text(_role),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.badge)),
            title: const Text('Identifier login'),
            subtitle: Text(_identifier),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _showChangePasswordSheet,
            icon: const Icon(Icons.vpn_key),
            label: const Text("Ganti Password"),
          ),
        ),

        const Expanded(child: LogsPage()),
      ],
    );
  }

  /// ==============================
  /// UI UNTUK WARGA
  /// ==============================
  Widget _buildWargaProfile() {
    return Column(
      children: [
        Expanded(
          child: DetailWargaPage(wargaId: _identifier, showAppBar: false),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showChangePasswordSheet,
            icon: const Icon(Icons.vpn_key),
            label: const Text("Ganti Password"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: _role == "warga" ? _buildWargaProfile() : _buildAdminProfile(),
    );
  }
}
