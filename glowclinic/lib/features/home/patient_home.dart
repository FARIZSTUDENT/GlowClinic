import 'package:flutter/material.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';
import 'package:glowclinic/features/catalog/catalog.dart';
import 'package:glowclinic/features/home/booking_list.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});
  @override
  State<PatientHome> createState() => _PH();
}

class _PH extends State<PatientHome> {
  int i = 0;
  @override
  Widget build(BuildContext c) {
    final pages = <Widget>[
      const Catalog(),
      BookingList(key: ValueKey(i), staff: false),
    ];
    final dests = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.spa), label: 'Layanan'),
      const NavigationDestination(icon: Icon(Icons.event), label: 'Booking'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('GlowClinic'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(c),
          ),
        ],
      ),
      body: pages.isEmpty
          ? const Center(child: Text('Selamat datang, pasien'))
          : IndexedStack(index: i, children: pages),
      bottomNavigationBar: dests.length < 2
          ? null
          : NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => setState(() => i = v),
              destinations: dests,
            ),
    );
  }
}
