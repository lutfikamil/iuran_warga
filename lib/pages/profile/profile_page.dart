import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'logs_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _role = '-';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionService.getRole();

    if (!mounted) return;

    setState(() {
      _role = role ?? '-';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = _role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Role pengguna'),
              subtitle: Text(_role),
            ),
          ),
          if (isAdmin)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Logs Aktivitas Admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Logs hanya dapat dilihat admin.'),
            ),
          const SizedBox(height: 8),
          Expanded(child: isAdmin ? const LogsPage() : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
