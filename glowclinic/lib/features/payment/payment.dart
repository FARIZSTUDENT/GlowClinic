import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/notif/inbox.dart';

/// Pasien: buat kode QR pembayaran simulasi.
Future<void> payQris(BuildContext c, Map b) async {
  if (b['status_bayar'] == 'lunas') {
    snack(c, 'Booking ini sudah lunas');
    return;
  }

  if (b['status'] == 'rejected' || b['status'] == 'cancelled') {
    snack(c, 'Booking ditolak/dibatalkan dan tidak dapat dibayar');
    return;
  }

  if (b['status'] != 'checked_in') {
    snack(
      c,
      b['status'] == 'done'
          ? 'Booking ini sudah selesai.'
          : 'Pembayaran dibuka setelah kamu check-in di klinik.',
    );
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

    await pushNotif(
      toStaff: true,
      judul: 'Pembayaran masuk 💸',
      isi: '${b['u_nama'] ?? 'Pasien'} membayar ${b['t_nama'] ?? 'treatment'} '
          '(Rp ${b['total_idr']}) via QRIS. Mohon verifikasi.',
      tipe: 'bayar',
      bookingId: b['id'] as int?,
    );
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

  final role = me.isEmpty ? '' : '${me.first['role']}'.trim().toLowerCase();

  if (!['staf', 'staff', 'admin'].contains(role)) {
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

  await pushNotif(
    userId: b['user_id'] as int?,
    judul: 'Pembayaran lunas ✅',
    isi: 'Pembayaran ${b['t_nama'] ?? 'treatment'} sudah diverifikasi. '
        'Terima kasih!',
    tipe: 'bayar',
    bookingId: b['id'] as int?,
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
