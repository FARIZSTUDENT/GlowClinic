import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:glowclinic/core/core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _ST();
}

class _ST extends State<SettingsScreen> {
  bool bio = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final value = await store.read(key: 'bio');

    if (!mounted) return;

    setState(() {
      bio = value == '1';
    });
  }

  Future<void> toggle(bool v) async {
    if (busy) return;

    setState(() {
      busy = true;
    });

    try {
      if (v) {
        final la = LocalAuthentication();
        final supported = await la.isDeviceSupported();
        final canCheck = await la.canCheckBiometrics;

        if (!mounted) return;

        if (!supported || !canCheck) {
          snack(context, 'Biometrik belum tersedia di perangkat ini');
          return;
        }

        final authenticated = await la.authenticate(
          localizedReason: 'Verifikasi untuk mengaktifkan biometrik',
        );

        if (!mounted) return;

        if (!authenticated) return;

        await store.write(key: 'bio', value: '1');
      } else {
        await store.delete(key: 'bio');
      }

      if (!mounted) return;

      setState(() {
        bio = v;
      });
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal mengubah pengaturan biometrik');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Login dengan biometrik'),
            subtitle: const Text('Sidik jari / wajah saat membuka aplikasi'),
            value: bio,
            onChanged: busy ? null : toggle,
          ),
        ],
      ),
    );
  }
}
