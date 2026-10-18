import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;
import 'package:glowclinic/features/notif/notif.dart';
import 'package:glowclinic/features/auth/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  await initNotif();
  await initDb();
  runApp(
    MaterialApp(
      title: 'GlowClinic',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFD4688A),
        useMaterial3: true,
      ),
      home: const Gate(),
    ),
  );
}
