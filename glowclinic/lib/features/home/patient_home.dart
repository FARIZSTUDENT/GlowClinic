import 'package:flutter/material.dart';

import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';
import 'package:glowclinic/features/catalog/catalog.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/home/booking_list.dart';
import 'package:glowclinic/features/bot/glowbot.dart';
import 'package:glowclinic/features/profile/profile.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PH();
}

class _PH extends State<PatientHome> {
  int i = 0;

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.spa_outlined),
      selectedIcon: Icon(Icons.spa),
      label: 'Layanan',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Cabang',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'Booking',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: 'GlowBot',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const Catalog(),
      const BranchMap(),
      BookingList(staff: false),
      const ChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GlowClinic'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: IndexedStack(index: i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (value) {
          if (value == i) return;
          setState(() => i = value);
        },
        destinations: destinations,
      ),
    );
  }
}
