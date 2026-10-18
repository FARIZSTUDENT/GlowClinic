import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';

class FeedbackScreen extends StatefulWidget {
  final Map b;

  const FeedbackScreen(this.b, {super.key});

  @override
  State<FeedbackScreen> createState() => _FB();
}

class _FB extends State<FeedbackScreen> {
  int rating = 5;
  final kesan = TextEditingController();
  final saran = TextEditingController();

  bool sending = false;

  @override
  void dispose() {
    kesan.dispose();
    saran.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending) return;

    final bookingId = widget.b['id'];

    if (bookingId == null || myId == null) {
      snack(context, 'Data booking atau pengguna tidak valid');
      return;
    }

    setState(() => sending = true);

    try {
      // Pastikan booking memang milik pengguna dan sudah selesai.
      final bookings = await qry(
        'SELECT id FROM bookings '
        'WHERE id = ? AND user_id = ? AND status = ?',
        [bookingId, myId, 'done'],
      );

      if (bookings.isEmpty) {
        if (mounted) {
          snack(context, 'Ulasan hanya dapat dikirim untuk treatment selesai');
        }
        return;
      }

      // Cegah ulasan ganda untuk booking yang sama.
      final existing = await qry(
        'SELECT id FROM feedback WHERE booking_id = ?',
        [bookingId],
      );

      if (existing.isNotEmpty) {
        if (mounted) {
          snack(context, 'Booking ini sudah memiliki ulasan');
        }
        return;
      }

      await db.insert('feedback', {
        'user_id': myId,
        'booking_id': bookingId,
        'rating': rating,
        'kesan': kesan.text.trim(),
        'saran': saran.text.trim(),
      });

      if (!mounted) return;

      Navigator.pop(context);
      snack(context, 'Terima kasih atas ulasanmu!');
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal mengirim ulasan. Silakan coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saran & Kesan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Bagaimana pengalaman treatment-mu?',
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i bintang',
                  icon: Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: sending ? null : () => setState(() => rating = i),
                ),
            ],
          ),
          TextField(
            controller: kesan,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Kesan',
              hintText: 'Ceritakan pengalaman treatment-mu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: saran,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Saran',
              hintText: 'Apa yang bisa kami tingkatkan?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: sending ? null : send,
            child: Text(sending ? 'Mengirim...' : 'Kirim'),
          ),
        ],
      ),
    );
  }
}

class FeedbackList extends StatelessWidget {
  const FeedbackList({super.key});

  Future<List<Map<String, dynamic>>> loadFeedback() {
    return qry(
      'SELECT f.*, u.nama AS u_nama '
      'FROM feedback f '
      'JOIN users u ON u.id = f.user_id '
      'ORDER BY f.id DESC',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ulasan Pasien')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: loadFeedback(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Gagal memuat ulasan pasien.'));
          }

          final feedback = snapshot.data ?? [];

          if (feedback.isEmpty) {
            return const Center(child: Text('Belum ada ulasan pasien.'));
          }

          return ListView.builder(
            itemCount: feedback.length,
            itemBuilder: (context, index) {
              final f = feedback[index];

              return ListTile(
                leading: CircleAvatar(child: Text('${f['rating'] ?? '-'}')),
                title: Text('${f['u_nama'] ?? 'Pasien'}'),
                subtitle: Text(
                  'Kesan: ${f['kesan'] ?? '-'}\n'
                  'Saran: ${f['saran'] ?? '-'}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
