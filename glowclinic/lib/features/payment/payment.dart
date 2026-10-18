import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';

/// Pasien: buat kode QR pembayaran simulasi.
Future<void> payQris(BuildContext c, Map b) async {
  if (b['status_bayar'] == 'lunas') {
    snack(c, 'Booking ini sudah lunas');
    return;
  }

  if (b['status'] == 'rejected') {
    snack(c, 'Booking ditolak dan tidak dapat dibayar');
    return;
  }

  String? code = b['kode_bayar'] as String?;

  if (code == null || code.isEmpty) {
    code = 'GLOW-${b['id']}-${newSalt().substring(0, 6)}';

    final updated = await db.update(
      'bookings',
      {
        'kode_bayar': code,
        'metode_bayar': 'qris',
        'status_bayar': 'menunggu_verifikasi',
      },
      where: 'id = ? AND user_id = ? AND status_bayar = ?',
      whereArgs: [b['id'], myId, 'belum_bayar'],
    );

    if (updated == 0) {
      if (c.mounted) {
        snack(c, 'Kode pembayaran gagal dibuat. Periksa status booking.');
      }
      return;
    }
  }

  if (!c.mounted) return;

  await Navigator.push(
    c,
    MaterialPageRoute(builder: (_) => QrisScreen(b['total_idr'], code!)),
  );
}

/// Staf: konfirmasi pembayaran setelah memeriksa bukti pembayaran.
Future<void> confirmPaid(BuildContext c, Map b) async {
  final me = await qry('SELECT role FROM users WHERE id = ?', [myId]);

  if (!c.mounted) return;

  if (me.isEmpty || me.first['role'] != 'staf') {
    snack(c, 'Hanya staf yang dapat mengonfirmasi pembayaran');
    return;
  }

  if (b['status_bayar'] != 'menunggu_verifikasi') {
    snack(c, 'Pembayaran belum menunggu verifikasi');
    return;
  }

  final updated = await db.update(
    'bookings',
    {'status_bayar': 'lunas'},
    where: 'id = ? AND status_bayar = ?',
    whereArgs: [b['id'], 'menunggu_verifikasi'],
  );

  if (!c.mounted) return;

  if (updated == 0) {
    snack(c, 'Status pembayaran berubah. Muat ulang booking.');
    return;
  }

  await Chain.add(
    'payment:${b['id']}:'
    '${DateTime.now().toUtc().toIso8601String()}',
  );

  if (!c.mounted) return;

  snack(c, 'Booking #${b['id']} LUNAS');
}

class QrisScreen extends StatelessWidget {
  final dynamic total;
  final String code;

  const QrisScreen(this.total, this.code, {super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Bayar dengan QRIS')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: code, size: 240),
            const SizedBox(height: 12),
            Text(
              'Rp $total',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(code),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tunjukkan kode ini kepada staf klinik. '
                'Ini adalah simulasi QRIS, bukan transaksi nyata.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
