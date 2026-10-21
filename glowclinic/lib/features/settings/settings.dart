import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/notif.dart';
import 'package:glowclinic/features/lbs/lbs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _ST();
}

class _ST extends State<SettingsScreen> {
  Future<void> updateBranchLocation() async {
    final position = await myPos();

    if (!mounted) return;

    if (position == null) {
      snack(context, 'Izin lokasi diperlukan');
      return;
    }

    try {
      final result = await db.update(
        'branches',
        {'lat': position.latitude, 'lng': position.longitude},
        where: 'id = ?',
        whereArgs: [1],
      );

      if (!mounted) return;

      snack(
        context,
        result > 0
            ? 'Lokasi cabang diperbarui'
            : 'Cabang dengan ID 1 tidak ditemukan',
      );
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal memperbarui lokasi cabang');
      }
    }
  }

  Future<void> testNotification() async {
    try {
      await notify(
        999999,
        'GlowClinic',
        'Notifikasi berjalan dengan baik',
        DateTime.now().add(const Duration(seconds: 5)),
      );

      if (mounted) {
        snack(context, 'Tes notifikasi dijadwalkan');
      }
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal menjadwalkan notifikasi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.fingerprint_rounded),
            title: Text('Login biometrik'),
            subtitle: Text(
              'Selalu aktif. Password dipakai setelah biometrik gagal 3 kali.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Jadikan lokasi saya sebagai lokasi cabang'),
            subtitle: const Text('Untuk menguji check-in saat demo'),
            onTap: updateBranchLocation,
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Tes notifikasi (5 detik)'),
            onTap: testNotification,
          ),
        ],
      ),
    );
  }
}
