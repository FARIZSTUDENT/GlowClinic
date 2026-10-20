
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/notif.dart';
import 'package:glowclinic/features/auth/auth.dart';

import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi timezone Jakarta
  tzd.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // 2. Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://hxjfutnvdydbxrhakurj.supabase.co',
    publishableKey: 'sb_publishable__3zuDY31J4PFqjdjk2KRKQ_NP79qKnX',
  );
  
  // 3. Inisialisasi notifikasi
  await initNotif();

  // 4. Inisialisasi database lokal SQLite
  await initDb();

  // 5. Jalankan aplikasi GlowClinic
  runApp(
    MaterialApp(
      title: 'GlowClinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF641F35),
        scaffoldBackgroundColor: const Color(0xFFFFF8F6),
        useMaterial3: true,
      ),
      home: const Gate(),
    ),
  );
}
