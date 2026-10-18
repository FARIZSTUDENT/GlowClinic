import 'package:flutter/material.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/home/booking_list.dart';
import 'package:glowclinic/features/feedback/feedback.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _SH();
}

class _SH extends State<StaffHome> {
  Future<void> verifyChain() async {
    try {
      final valid = await Chain.valid();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            valid ? Icons.verified : Icons.warning_amber,
            color: valid ? Colors.green : Colors.red,
            size: 36,
          ),
          title: Text(valid ? 'Rantai VALID' : 'Rantai RUSAK'),
          content: Text(
            valid
                ? 'Integritas rantai blockchain berhasil diverifikasi.'
                : 'Verifikasi gagal. Periksa data rantai blockchain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memverifikasi blockchain.')),
      );
    }
  }

  Future<void> confirmLogout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu perlu login kembali untuk mengakses dashboard staf.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yes == true && mounted) {
      await logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Staf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review),
            tooltip: 'Ulasan pasien',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackList()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.verified),
            tooltip: 'Verifikasi blockchain',
            onPressed: verifyChain,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: confirmLogout,
          ),
        ],
      ),
      body: const BookingList(staff: true),
    );
  }
}
