import 'package:flutter/material.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/home/booking_list.dart';
import 'package:glowclinic/features/feedback/feedback.dart';
import 'package:glowclinic/features/notif/inbox.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _SH();
}

class _SH extends State<StaffHome> {
  @override
  void initState() {
    super.initState();
    startNotifWatcher();
  }

  Future<void> verifyChain() async {
    try {
      final r = await Chain.verifyOnChain();

      if (!mounted) return;

      final ok = r.ok;
      final lines = <String>[
        r.localValid
            ? 'Rantai lokal: valid (${r.total} blok).'
            : 'Rantai lokal: RUSAK, data pernah diubah.',
        'Terbukti di blockchain: ${r.anchored} blok.',
        if (r.pending > 0) 'Menunggu dikirim: ${r.pending} blok.',
        if (r.missing > 0)
          'Tidak ditemukan di blockchain: ${r.missing} blok.',
        if (r.error != null) 'Blockchain: ${r.error}',
      ];

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            ok ? Icons.verified : Icons.warning_amber,
            color: ok ? Colors.green : Colors.red,
            size: 36,
          ),
          title: Text(ok ? 'Rantai VALID' : 'Perlu diperiksa'),
          content: Text(lines.join('\n')),
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
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dashboard Staf'),
            SizedBox(height: 2),
            Text(
              'Kelola operasional GlowClinic',
              style: TextStyle(
                color: Color(0xFF9A7B84),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          const NotifBell(),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              switch (v) {
                case 'ulasan':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackList()),
                  );
                  break;
                case 'promo':
                  sendPromoDialog(context);
                  break;
                case 'chain':
                  verifyChain();
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'promo', child: Text('Kirim promo ke pasien')),
              PopupMenuItem(value: 'ulasan', child: Text('Ulasan pasien')),
              PopupMenuItem(
                  value: 'chain', child: Text('Verifikasi blockchain')),
              PopupMenuItem(value: 'settings', child: Text('Pengaturan')),
            ],
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
