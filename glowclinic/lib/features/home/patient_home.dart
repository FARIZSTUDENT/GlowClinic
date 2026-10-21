import 'package:flutter/material.dart';

import 'package:glowclinic/core/core.dart';

import 'package:glowclinic/features/catalog/catalog.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/home/booking_list.dart';
import 'package:glowclinic/features/bot/glowbot.dart';
import 'package:glowclinic/features/profile/profile.dart';
import 'package:glowclinic/features/notif/inbox.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PH();
}

class _PH extends State<PatientHome> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    startNotifWatcher();
    setupPatientPromos();
  }

  static const Color background = Color(0xFFFFF7F9);
  static const Color primary = Color(0xFF87364B);
  static const Color lightPurple = Color(0xFFFFE1EA);
  static const Color textColor = Color(0xFF59434C);
  static const Color mutedColor = Color(0xFFB08C99);

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.spa_outlined),
      selectedIcon: Icon(Icons.spa_rounded),
      label: 'Home',
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

        titleSpacing: 16,

        title: Row(
          children: [
            // LOGO GLOWCLINIC
            Image.asset(
              'assets/images/glowclinic_logo.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.spa_outlined,
                    size: 30,
                    color: primary,
                  ),
                );
              },
            ),

            const SizedBox(width: 8),

            // NAMA BRAND DAN TAGLINE
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GlowClinic',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Book Your Dermatologist, Track Your Glow',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        actions: const [
          NotifBell(),
          SizedBox(width: 8),
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

              if (value == 2) {
                bookingRefresh.value++;
              }
            },
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
