import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:timezone/data/latest.dart' as tzd;

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
      home: const Scaffold(body: Center(child: Text('GlowClinic'))),
    ),
  );
}
