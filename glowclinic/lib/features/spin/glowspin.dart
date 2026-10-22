import 'dart:async';
import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/notif/notif.dart';

const prizes = [
  'Diskon 5%',
  '+50 Poin',
  'Sampel Sunscreen',
  'Gratis Konsultasi',
  '+100 Poin',
  'Diskon 10%',
];

const _maroon = Color(0xFF641F35);
const _deepMaroon = Color(0xFF481526);
const _champagne = Color(0xFFC89B63);
const _cream = Color(0xFFFFF8F3);
const _ink = Color(0xFF49343B);
const _muted = Color(0xFF9A7B84);

class WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final segment = 2 * m.pi / prizes.length;
    const colors = [
      Color(0xFF641F35),
      Color(0xFF8B4A5D),
      Color(0xFFB97986),
      Color(0xFFD5A77E),
      Color(0xFF9C5B6C),
      Color(0xFF542237),
    ];

    canvas.drawCircle(
      center,
      radius + 5,
      Paint()
        ..color = _champagne
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _deepMaroon
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    for (var i = 0; i < prizes.length; i++) {
      canvas.drawArc(
        rect,
        -m.pi / 2 + i * segment,
        segment,
        true,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.fill,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: prizes[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: 70);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-m.pi / 2 + (i + 0.5) * segment);
      canvas.translate(radius * 0.55, 0);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    for (var i = 0; i < prizes.length; i++) {
      final angle = -m.pi / 2 + i * segment;
      final start = Offset(
        center.dx + m.cos(angle) * 12,
        center.dy + m.sin(angle) * 12,
      );
      final end = Offset(
        center.dx + m.cos(angle) * radius,
        center.dy + m.sin(angle) * radius,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = 1,
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _champagne
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      radius * 0.17,
      Paint()..color = _cream,
    );
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = _maroon,
    );
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = _champagne
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) => false;
}

class SpinScreen extends StatefulWidget {
  final Map b;

  const SpinScreen(this.b, {super.key});

  @override
  State<SpinScreen> createState() => _SP();
}

class _SP extends State<SpinScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  double rot = 0;
  String? hasil;
  bool busy = false;
  StreamSubscription<AccelerometerEvent>? sub;

  @override
  void initState() {
    super.initState();
    final savedPrize = widget.b['spin_hadiah']?.toString();
    if (savedPrize != null && savedPrize.isNotEmpty && savedPrize != 'null') {
      hasil = savedPrize;
    }

    sub = accelerometerEventStream().listen(
      (event) {
        final magnitude = m.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        if (magnitude > 25 && !busy && hasil == null) {
          spin();
        }
      },
      onError: (Object error) {
        // Tombol Putar tetap dapat digunakan jika sensor gagal.
      },
    );
  }

  @override
  void dispose() {
    sub?.cancel();
    ac.dispose();
    super.dispose();
  }

  Future<void> spin() async {
    if (busy || hasil != null) return;

    final bid = int.tryParse(widget.b['id'].toString());
    if (bid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID booking tidak valid')));
      return;
    }

    setState(() => busy = true);

    try {
      final prize = await spinWheel(bid);

      if (!mounted) return;

      if (prize == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kesempatan spin tidak tersedia atau sudah digunakan',
            ),
          ),
        );
        return;
      }

      await syncAftercareReminders(bid, userId: myId);

      final index = prizes.indexOf(prize);

      if (index < 0) {
        setState(() => hasil = prize);
        return;
      }

      final segment = 2 * m.pi / prizes.length;
      final target = 2 * m.pi * 5 - (index + 0.5) * segment;

      ac.reset();

      final animation = Tween<double>(
        begin: 0,
        end: target,
      ).animate(CurvedAnimation(parent: ac, curve: Curves.easeOut));

      void updateRotation() {
        if (mounted) {
          setState(() => rot = animation.value);
        }
      }

      animation.addListener(updateRotation);

      try {
        await ac.forward();
      } finally {
        animation.removeListener(updateRotation);
      }

      if (!mounted) return;

      // Hadiah sudah disimpan di database.
      // Kegagalan blockchain tidak boleh menghapus hasil hadiah.
      try {
        await Chain.add('spin:$bid:$prize');
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hadiah tersimpan, tetapi pencatatan blockchain gagal.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() => hasil = prize);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Spin gagal: $e')));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingCode = '#${widget.b['id'] ?? '-'}';
    final treatment =
        widget.b['treatment_nama']?.toString() ?? 'Perawatan GlowClinic';

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: const Text('GlowSpin'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'REWARD LOUNGE',
                style: TextStyle(
                  color: _champagne,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _maroon,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _maroon.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _champagne,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hadiah spesial untukmu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$treatment  •  $bookingCode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Putar keberuntunganmu',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Kocok perangkat atau tekan tombol untuk menemukan hadiah.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _maroon.withValues(alpha: 0.12),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: rot,
                      child: CustomPaint(
                        size: const Size(290, 290),
                        painter: WheelPainter(),
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 44,
                  color: _champagne,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !busy && hasil == null ? spin : null,
                icon: Icon(
                  busy ? Icons.hourglass_top_rounded : Icons.casino_rounded,
                ),
                label: Text(busy ? 'Hadiah sedang dipilih...' : 'Putar roda'),
              ),
            ),
            if (hasil != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _champagne.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: _champagne.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: _champagne,
                      size: 38,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selamat, kamu mendapatkan',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasil!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _maroon,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hadiah telah tersimpan di akunmu.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Text(
                  'Satu kesempatan untuk setiap booking yang selesai dan lunas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Undian hadiah: satu kali untuk setiap booking yang selesai dan lunas.
Future<String?> spinWheel(int bid) async {
  return db.transaction<String?>((txn) async {
    final rows = await txn.query(
      'bookings',
      columns: ['id'],
      where: 'id = ? AND user_id = ? AND status = ? '
          'AND status_bayar = ? AND spin_hadiah IS NULL',
      whereArgs: [bid, myId, 'done', 'lunas'],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final random = m.Random.secure().nextDouble();

    final prize = random < 0.30
        ? 'Diskon 5%'
        : random < 0.50
            ? '+50 Poin'
            : random < 0.70
                ? 'Sampel Sunscreen'
                : random < 0.85
                    ? 'Gratis Konsultasi'
                    : random < 0.95
                        ? '+100 Poin'
                        : 'Diskon 10%';

    // Klaim kesempatan spin hanya jika belum ada hadiah.
    final updated = await txn.update(
      'bookings',
      {'spin_hadiah': prize},
      where: 'id = ? AND user_id = ? AND status = ? '
          'AND status_bayar = ? AND spin_hadiah IS NULL',
      whereArgs: [bid, myId, 'done', 'lunas'],
    );

    if (updated == 0) return null;

    if (prize == '+50 Poin') {
      await txn.rawUpdate(
        'UPDATE users SET poin = COALESCE(poin, 0) + 50 WHERE id = ?',
        [myId],
      );
    } else if (prize == '+100 Poin') {
      await txn.rawUpdate(
        'UPDATE users SET poin = COALESCE(poin, 0) + 100 WHERE id = ?',
        [myId],
      );
    }

    return prize;
  });
}
