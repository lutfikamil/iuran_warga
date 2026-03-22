import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const AppCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.blue),

            const SizedBox(height: 10),

            Text(title, style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 10),

            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
