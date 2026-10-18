import 'package:flutter/material.dart';
import 'package:glowclinic/features/auth/auth.dart';

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
        IconButton(icon: const Icon(Icons.logout), onPressed: () => logout(c)),
      ],
    ),
    body: const Center(child: Text('Dashboard staf')),
  );
}
