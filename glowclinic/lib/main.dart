import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:glowclinic/features/auth/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzd.initializeTimeZones();
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
