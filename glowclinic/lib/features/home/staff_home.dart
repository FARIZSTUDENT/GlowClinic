import 'package:flutter/material.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';
import 'package:glowclinic/features/blockchain/chain.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});
  @override
  State<StaffHome> createState() => _SH();
}

class _SH extends State<StaffHome> {
  int n = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Dashboard Staf'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.verified),
          tooltip: 'Verifikasi blockchain',
          onPressed: () async {
            final ok = await Chain.valid();
            if (!c.mounted) return;
            showDialog(
              context: c,
              builder: (_) => AlertDialog(
                title: Text(ok ? 'Rantai VALID' : 'Rantai RUSAK'),
              ),
            );
          },
        ),
        IconButton(icon: const Icon(Icons.logout), onPressed: () => logout(c)),
      ],
    ),
    body: const Center(child: Text('Dashboard staf')),
  );
}
