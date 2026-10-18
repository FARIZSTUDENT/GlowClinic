import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/payment/payment.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';
import 'package:glowclinic/features/spin/glowspin.dart';
import 'package:glowclinic/features/notif/notif.dart';

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

    final bookings = await qry(sql, widget.staff ? [] : [myId]);

    if (!widget.staff) {
      for (final booking in bookings) {
        await syncNotif(booking);
      }
    }

    return bookings;
  }

  void reload() {
    if (!mounted) return;

    setState(() {
      _future = load();
    });
  }

  Future<void> setStatus(Map b, String status) async {
    if (!widget.staff) return;

    final oldStatus = b['status'];
    if (oldStatus == status) return;

    await db.update(
      'bookings',
      {'status': status},
      where: 'id = ?',
      whereArgs: [b['id']],
    );

    if (status == 'done' && oldStatus != 'done') {
      await Chain.add(
        'record:${b['id']}:'
        '${sha('${b['catatan_dokter'] ?? ''}')}:'
        '${DateTime.now().toUtc().toIso8601String()}',
      );
    }
  }

  Future<void> note(BuildContext context, Map b) async {
    if (!widget.staff) return;

    final controller = TextEditingController(
      text: b['catatan_dokter']?.toString() ?? '',
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rekam treatment'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tindakan, produk, kondisi kulit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (result != true) return;

      await db.update(
        'bookings',
        {'catatan_dokter': controller.text.trim()},
        where: 'id = ?',
        whereArgs: [b['id']],
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> act(BuildContext context, Map b, String action) async {
    try {
      switch (action) {
        case 'info':
          return;

        case 'bayar':
          await payQris(context, b);
          break;

        case 'lunas':
          await confirmPaid(context, b);
          break;

        case 'checkin':
          await doCheckIn(context, b);
          break;

        case 'foto':
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PhotoScreen(b)),
          );
          break;

        case 'spin':
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpinScreen(b)),
          );
          break;

        case 'catatan':
          await note(context, b);
          break;

        default:
          await setStatus(b, action);
      }

      if (!mounted) return;
      reload();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context)
          .showSnackBar(SnackBar(content: Text('Aksi gagal: $e')));

      reload();
    }
  }

  String formatBookingTime(dynamic value) {
    try {
      return zoneText(DateTime.parse(value.toString()).toUtc());
    } catch (_) {
      return 'Waktu booking tidak valid';
    }
  }

  @override
  Widget build(BuildContext context) {
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

        return RefreshIndicator(
          onRefresh: () async {
            final future = load();

            setState(() {
              _future = future;
            });

            await future;
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];

              final status = b['status']?.toString() ?? '-';
              final payment = b['status_bayar']?.toString() ?? '-';

              final subtitle = [
                if (widget.staff) b['u_nama']?.toString() ?? '',
                formatBookingTime(b['waktu_utc']),
                'Status: $status',
                'Bayar: $payment (Rp ${b['total_idr'] ?? 0})',
                if (b['catatan_dokter'] != null &&
                    b['catatan_dokter'].toString().isNotEmpty)
                  'Catatan: ${b['catatan_dokter']}',
                if (b['spin_hadiah'] != null) 'Hadiah: ${b['spin_hadiah']}',
              ].where((text) => text.isNotEmpty).join('\n');

              return Card(
                child: ListTile(
                  title: Text('${b['t_nama']} - ${b['d_nama']}'),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => act(context, b, value),
                    itemBuilder: (_) {
                      if (widget.staff) {
                        return [
                          for (final value in [
                            'confirmed',
                            'rejected',
                            'checked_in',
                            'in_treatment',
                            'done',
                            'catatan',
                            'foto',
                            'lunas',
                          ])
                            PopupMenuItem(value: value, child: Text(value)),
                        ];
                      }

                      return [
                        if (payment != 'lunas' && status != 'rejected')
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
                            payment == 'lunas' &&
                            b['spin_hadiah'] == null)
                          const PopupMenuItem(
                            value: 'spin',
                            child: Text('GlowSpin'),
                          ),
                        const PopupMenuItem(
                          value: 'info',
                          child: Text('Detail'),
                        ),
                      ];
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
