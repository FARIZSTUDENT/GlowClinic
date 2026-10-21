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
  final currency = b['mata_uang']?.toString() ?? 'IDR';
  final rate = (b['kurs'] as num?)?.toDouble() ?? CurrencyService.getRate(currency);
  final totalIdr = (b['total_idr'] as num?)?.toInt() ?? 0;
  final totalBayar = (b['total_bayar'] as num?)?.toDouble() ??
      CurrencyService.convertFromIdr(totalIdr, currency, customRate: rate);

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

    final formattedBayar = CurrencyService.formatMoney(totalBayar, currency);
    final displaySummary = currency == 'IDR'
        ? 'Rp ${CurrencyService.formatAmount(totalIdr, 'IDR')}'
        : '$formattedBayar (Dasar: Rp ${CurrencyService.formatAmount(totalIdr, 'IDR')})';

    await pushNotif(
      toStaff: true,
      judul: 'Pembayaran masuk 💸',
      isi: '${b['u_nama'] ?? 'Pasien'} membayar ${b['t_nama'] ?? 'treatment'} '
          '($displaySummary) via QRIS. Mohon verifikasi.',
      tipe: 'bayar',
      bookingId: b['id'] as int?,
    );
  }

  if (!c.mounted) return;

  final bookingMap = Map<String, dynamic>.from(b);
  bookingMap['kode_bayar'] = code;
  bookingMap['mata_uang'] = currency;
  bookingMap['kurs'] = rate;
  bookingMap['total_bayar'] = totalBayar;
  bookingMap['total_idr'] = totalIdr;

  await Navigator.push(
    c,
    MaterialPageRoute(builder: (_) => QrisScreen(booking: bookingMap, code: code!)),
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

  final currency = b['mata_uang']?.toString() ?? 'IDR';
  final totalBayar = b['total_bayar'] ?? b['total_idr'];

  await Chain.add(
    'payment:${b['id']}:$currency:$totalBayar:${b['total_idr']}:'
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
  final Map<String, dynamic> booking;
  final String code;

  const QrisScreen({
    super.key,
    required this.booking,
    required this.code,
  });

  @override
  Widget build(BuildContext c) {
    final currency = booking['mata_uang']?.toString() ?? 'IDR';
    final totalIdr = (booking['total_idr'] as num?)?.toInt() ?? 0;
    final rate = (booking['kurs'] as num?)?.toDouble() ?? CurrencyService.getRate(currency);
    final totalBayar = (booking['total_bayar'] as num?)?.toDouble() ??
        CurrencyService.convertFromIdr(totalIdr, currency, customRate: rate);

    final formattedPrimary = CurrencyService.formatMoney(totalBayar, currency);
    final formattedIdr = 'Rp ${CurrencyService.formatAmount(totalIdr, 'IDR')}';
    final treatmentName = booking['t_nama']?.toString() ?? 'Treatment GlowClinic';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F6),
      appBar: AppBar(
        title: const Text('Bayar dengan QRIS'),
        backgroundColor: const Color(0xFFFFF8F6),
        foregroundColor: const Color(0xFF49343B),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        treatmentName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF49343B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      QrImageView(
                        data: code,
                        size: 210,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        formattedPrimary,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF641F35),
                        ),
                      ),
                      if (currency != 'IDR') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E4E8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Dasar QRIS: $formattedIdr',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF641F35),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF3E4E8)),
                  ),
                  child: Column(
                    children: [
                      _rowInfo('Mata Uang Transaksi', '$currency (${supportedCurrencies[currency]?.symbol ?? ''})'),
                      const Divider(height: 16),
                      _rowInfo('Nominal Transaksi', formattedPrimary),
                      if (currency != 'IDR') ...[
                        const Divider(height: 16),
                        _rowInfo(
                          'Kurs Konversi',
                          CurrencyService.formatRateDescription(currency, customRate: rate),
                        ),
                      ],
                      const Divider(height: 16),
                      _rowInfo('Nominal Tagihan Gateway (IDR)', formattedIdr),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currency == 'IDR'
                              ? 'Pembayaran simulasi QRIS diproses dalam mata uang Rupiah (IDR) sebesar $formattedIdr. Tunjukkan kode QR kepada staf klinik.'
                              : 'Integritas Pembayaran: Sesuai regulasi sistem pembayaran QRIS Indonesia, settlement pembayaran ditagihkan dalam Rupiah (IDR) sebesar $formattedIdr. Nilai $formattedPrimary adalah konversi transaksi resmi sesuai kurs $currency.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9A7B84), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF49343B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

