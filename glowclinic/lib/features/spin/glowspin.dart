import 'dart:async';
import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';

const prizes = [
  'Diskon 5%',
  '+50 Poin',
  'Sampel Sunscreen',
  'Gratis Konsultasi',
  '+100 Poin',
  'Diskon 10%',
];

class WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final segment = 2 * m.pi / prizes.length;

    for (var i = 0; i < prizes.length; i++) {
      canvas.drawArc(
        rect,
        -m.pi / 2 + i * segment,
        segment,
        true,
        Paint()..color = i.isEven ? Colors.pink.shade200 : Colors.pink.shade50,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: prizes[i],
          style: const TextStyle(color: Colors.black, fontSize: 10),
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.pink.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
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
    return Scaffold(
      appBar: AppBar(title: const Text('GlowSpin')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kocok HP atau tekan Putar!'),
              const Icon(Icons.arrow_drop_down, size: 40, color: Colors.pink),
              Transform.rotate(
                angle: rot,
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: WheelPainter(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: !busy && hasil == null ? spin : null,
                child: Text(busy ? 'Memutar...' : 'Putar'),
              ),
              if (hasil != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Selamat! Kamu dapat: $hasil',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
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
      where:
          'id = ? AND user_id = ? AND status = ? '
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
      where:
          'id = ? AND user_id = ? AND status = ? '
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
