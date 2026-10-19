
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

  static const Color background = Color(0xFFFFF7F9);
  static const Color primary = Color(0xFFE879A0);
  static const Color lightPurple = Color(0xFFFFE1EA);
  static const Color lightPink = Color(0xFFFFF0F4);
  static const Color textColor = Color(0xFF59434C);
  static const Color mutedColor = Color(0xFFB08C99);

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.spa_outlined),
      selectedIcon: Icon(Icons.spa_rounded),
      label: 'Layanan',
    ),
    NavigationDestination(
      icon: Icon(Icons.location_on_outlined),
      selectedIcon: Icon(Icons.location_on_rounded),
      label: 'Cabang',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Booking',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'GlowBot',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
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
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GlowClinic',
              style: TextStyle(
                color: textColor,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Your skin, your confidence',
              style: TextStyle(
                color: mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: lightPurple,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Pengaturan',
              icon: const Icon(
                Icons.settings_outlined,
                color: primary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 5),
            decoration: BoxDecoration(
              color: lightPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Keluar',
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD85F89),
              ),
              onPressed: () => logout(context),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: i,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 76,
            indicatorColor: lightPurple,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            labelTextStyle:
                WidgetStateProperty.resolveWith<TextStyle>(
              (states) {
                final selected =
                    states.contains(WidgetState.selected);

                return TextStyle(
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected ? primary : mutedColor,
                );
              },
            ),
            iconTheme:
                WidgetStateProperty.resolveWith<IconThemeData>(
              (states) {
                final selected =
                    states.contains(WidgetState.selected);

                return IconThemeData(
                  size: 22,
                  color: selected ? primary : mutedColor,
                );
              },
            ),
          ),
          child: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (value) {
              if (value == i) return;
              setState(() => i = value);
            },
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
