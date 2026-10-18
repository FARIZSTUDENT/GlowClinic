import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/payment/payment.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';
import 'package:glowclinic/features/spin/glowspin.dart';

class BookingList extends StatefulWidget {
  final bool staff;

  const BookingList({super.key, required this.staff});

  @override
  State<BookingList> createState() => _BL();
}

class _BL extends State<BookingList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    const baseSql =
        'SELECT b.*, t.nama AS t_nama, d.nama AS d_nama, '
        'u.nama AS u_nama FROM bookings b '
        'JOIN treatments t ON t.id = b.treatment_id '
        'JOIN doctors d ON d.id = b.doctor_id '
        'JOIN users u ON u.id = b.user_id ';

    final sql = widget.staff
        ? '${baseSql}ORDER BY b.waktu_utc DESC'
        : '${baseSql}WHERE b.user_id = ? '
              'ORDER BY b.waktu_utc DESC';

    return qry(sql, widget.staff ? [] : [myId]);
  }

  void reload() {
    if (!mounted) return;
    setState(() {
      _future = load();
    });
  }

  Future<void> setStatus(Map b, String status) async {
    if (!widget.staff) return;

    final previousStatus = b['status'];

    if (previousStatus == status) return;

    await db.update(
      'bookings',
      {'status': status},
      where: 'id = ?',
      whereArgs: [b['id']],
    );

    // Catat ke blockchain hanya saat pertama kali menjadi done.
    if (status == 'done' && previousStatus != 'done') {
      await Chain.add(
        'record:${b['id']}:'
        '${sha('${b['catatan_dokter'] ?? ''}')}:'
        '${DateTime.now().toUtc().toIso8601String()}',
      );
    }
  }

  Future<void> note(BuildContext c, Map b) async {
    if (!widget.staff) return;

    final ctl = TextEditingController(
      text: b['catatan_dokter']?.toString() ?? '',
    );

    try {
      final ok = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
          title: const Text('Rekam treatment'),
          content: TextField(
            controller: ctl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tindakan, produk, kondisi kulit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (ok != true) return;

      await db.update(
        'bookings',
        {'catatan_dokter': ctl.text.trim()},
        where: 'id = ?',
        whereArgs: [b['id']],
      );
    } finally {
      ctl.dispose();
    }
  }

  Future<void> act(BuildContext c, Map b, String v) async {
    try {
      switch (v) {
        case 'info':
          return;

        case 'bayar':
          await payQris(c, b);
          break;

        case 'lunas':
          await confirmPaid(c, b);
          break;

        case 'checkin':
          await doCheckIn(c, b);
          break;

        case 'foto':
          await Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => PhotoScreen(b)),
          );
          break;

        case 'spin':
          await Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => SpinScreen(b)),
          );
          break;

        case 'catatan':
          await note(c, b);
          break;

        default:
          await setStatus(b, v);
      }

      if (!mounted) return;
      reload();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Aksi gagal: $e')));

      reload();
    }
  }

  String bookingTime(dynamic value) {
    try {
      return zoneText(DateTime.parse(value.toString()).toUtc());
    } catch (_) {
      return 'Waktu booking tidak valid';
    }
  }

  @override
  Widget build(BuildContext c) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gagal memuat booking: ${snapshot.error}'),
                const SizedBox(height: 8),
                FilledButton(onPressed: reload, child: const Text('Coba lagi')),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!;

        if (bookings.isEmpty) {
          return const Center(child: Text('Belum ada booking'));
        }

        return ListView.builder(
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final b = bookings[index];

            final status = b['status']?.toString() ?? '-';
            final paymentStatus = b['status_bayar']?.toString() ?? '-';
            final hasPrize = b['spin_hadiah'] != null;

            final subtitle = [
              if (widget.staff) b['u_nama']?.toString() ?? '',
              bookingTime(b['waktu_utc']),
              'Status: $status',
              'Bayar: $paymentStatus (Rp ${b['total_idr'] ?? 0})',
              if (b['catatan_dokter'] != null &&
                  b['catatan_dokter'].toString().isNotEmpty)
                'Catatan: ${b['catatan_dokter']}',
              if (hasPrize) 'Hadiah: ${b['spin_hadiah']}',
            ].where((s) => s.isNotEmpty).join('\n');

            return Card(
              child: ListTile(
                title: Text('${b['t_nama']} - ${b['d_nama']}'),
                subtitle: Text(subtitle),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => act(context, b, v),
                  itemBuilder: (_) {
                    if (widget.staff) {
                      return [
                        for (final v in [
                          'confirmed',
                          'rejected',
                          'checked_in',
                          'in_treatment',
                          'done',
                          'catatan',
                          'foto',
                          'lunas',
                        ])
                          PopupMenuItem(value: v, child: Text(v)),
                      ];
                    }

                    return [
                      if (paymentStatus != 'lunas' && status != 'rejected')
                        const PopupMenuItem(
                          value: 'bayar',
                          child: Text('Bayar QRIS'),
                        ),
                      if (status == 'confirmed')
                        const PopupMenuItem(
                          value: 'checkin',
                          child: Text('Check-in'),
                        ),
                      if ([
                        'checked_in',
                        'in_treatment',
                        'done',
                      ].contains(status))
                        const PopupMenuItem(
                          value: 'foto',
                          child: Text('Foto before/after'),
                        ),
                      if (status == 'done' &&
                          paymentStatus == 'lunas' &&
                          !hasPrize)
                        const PopupMenuItem(
                          value: 'spin',
                          child: Text('GlowSpin'),
                        ),
                      const PopupMenuItem(value: 'info', child: Text('Detail')),
                    ];
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
