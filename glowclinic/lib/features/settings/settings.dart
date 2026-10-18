import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/lbs/lbs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _ST();
}

class _ST extends State<SettingsScreen> {
  bool bio = false;
  bool savingBio = false;
  bool updatingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    try {
      final value = await store.read(key: 'bio');

      if (!mounted) return;

      setState(() {
        bio = value == '1';
      });
    } catch (_) {
      if (!mounted) return;
      snack(context, 'Gagal membaca pengaturan biometrik.');
    }
  }

  Future<void> toggle(bool value) async {
    if (savingBio) return;

    setState(() {
      savingBio = true;
    });

    try {
      if (value) {
        final auth = LocalAuthentication();

        final supported = await auth.isDeviceSupported();
        final canCheck = await auth.canCheckBiometrics;
        final available = await auth.getAvailableBiometrics();

        if (!supported || !canCheck || available.isEmpty) {
          if (mounted) {
            snack(context, 'Biometrik belum tersedia di perangkat ini.');
          }
          return;
        }

        final authenticated = await auth.authenticate(
          localizedReason: 'Verifikasi untuk mengaktifkan biometrik',
        );

        if (!authenticated) return;

        await store.write(key: 'bio', value: '1');
      } else {
        await store.delete(key: 'bio');
      }

      if (!mounted) return;

      setState(() {
        bio = value;
      });

      snack(
        context,
        value
            ? 'Login biometrik berhasil diaktifkan.'
            : 'Login biometrik dinonaktifkan.',
      );
    } catch (_) {
      if (mounted) {
        snack(context, 'Gagal mengubah pengaturan biometrik.');
      }
    } finally {
      if (mounted) {
        setState(() {
          savingBio = false;
        });
      }
    }
  }

  Future<void> _updateBranchLocation() async {
    if (updatingLocation) return;

    setState(() {
      updatingLocation = true;
    });

    try {
      final position = await myPos();

      if (!mounted) return;

      if (position == null) {
        snack(context, 'Aktifkan lokasi dan izinkan akses lokasi.');
        return;
      }

      await db.update(
        'branches',
        {'lat': position.latitude, 'lng': position.longitude},
        where: 'id = ?',
        whereArgs: [1],
      );

      if (!mounted) return;

      snack(context, 'Lokasi cabang berhasil diperbarui.');
    } catch (_) {
      if (mounted) {
        snack(context, 'Gagal memperbarui lokasi cabang.');
      }
    } finally {
      if (mounted) {
        setState(() {
          updatingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Login dengan biometrik'),
            subtitle: const Text('Sidik jari / wajah saat membuka aplikasi'),
            value: bio,
            onChanged: savingBio ? null : toggle,
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Jadikan lokasi saya sebagai lokasi cabang'),
            subtitle: const Text('Untuk menguji check-in saat demo'),
            trailing: updatingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: updatingLocation ? null : _updateBranchLocation,
          ),
        ],
      ),
    );
  }
}
