import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/payment/payment.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';

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
    final sql =
        'select b.*, t.nama t_nama, d.nama d_nama, u.nama u_nama '
        'from bookings b '
        'join treatments t on t.id = b.treatment_id '
        'join doctors d on d.id = b.doctor_id '
        'join users u on u.id = b.user_id '
        '${widget.staff ? '' : 'where b.user_id = ? '}'
        'order by b.waktu_utc desc';

    final rows = widget.staff ? await qry(sql) : await qry(sql, [myId]);

    return List<Map<String, dynamic>>.from(rows);
  }

  void refresh() {
    if (!mounted) return;

    setState(() {
      _future = load();
    });
  }

  Future<void> setStatus(Map<String, dynamic> booking, String status) async {
    if (!widget.staff) return;

    await db.update(
      'bookings',
      {'status': status},
      where: 'id = ?',
      whereArgs: [booking['id']],
    );

    if (status == 'done') {
      final noteText = booking['catatan_dokter']?.toString() ?? '';

      final record =
          'record:${booking['id']}:${sha(noteText)}:'
          '${DateTime.now().toUtc().toIso8601String()}';

      await Chain.add(record);
    }
  }

  Future<void> note(BuildContext context, Map<String, dynamic> booking) async {
    if (!widget.staff || !context.mounted) return;

    final controller = TextEditingController(
      text: booking['catatan_dokter']?.toString() ?? '',
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

      if (result != true || !mounted) return;

      await db.update(
        'bookings',
        {'catatan_dokter': controller.text.trim()},
        where: 'id = ?',
        whereArgs: [booking['id']],
      );

      if (!mounted) return;

      snack(this.context, 'Catatan treatment berhasil disimpan.');
    } finally {
      controller.dispose();
    }
  }

  Future<void> act(
    BuildContext context,
    Map<String, dynamic> booking,
    String value,
  ) async {
    try {
      switch (value) {
        case 'info':
          if (!context.mounted) return;
          snack(context, 'Status booking: ${booking['status']}');
          break;

        case 'bayar':
          if (widget.staff || !context.mounted) return;
          await payQris(context, booking);
          break;

        case 'lunas':
          if (!widget.staff || !context.mounted) return;
          await confirmPaid(context, booking);
          break;

        case 'checkin':
          if (widget.staff || !context.mounted) return;
          await doCheckIn(context, booking);
          break;

        case 'foto':
          if (!context.mounted) return;

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PhotoScreen(booking)),
          );
          break;

        case 'catatan':
          if (!widget.staff || !context.mounted) return;
          await note(context, booking);
          break;

        default:
          if (!widget.staff) return;

          await setStatus(booking, value);

          if (!mounted) return;

          snack(this.context, 'Status booking diperbarui.');
      }
    } catch (_) {
      if (!mounted) return;
      snack(this.context, 'Gagal memproses booking.');
    } finally {
      if (mounted) {
        refresh();
      }
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return 'Waktu belum tersedia';

    try {
      return zoneText(DateTime.parse(value.toString()).toUtc());
    } catch (_) {
      return 'Format waktu tidak valid';
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
                const Text('Gagal memuat daftar booking.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: refresh,
                  child: const Text('Coba Lagi'),
                ),
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
              final booking = bookings[index];
              final status = booking['status']?.toString() ?? '-';
              final paymentStatus = booking['status_bayar']?.toString() ?? '-';
              final noteText = booking['catatan_dokter']?.toString();

              return Card(
                child: ListTile(
                  title: Text(
                    '${booking['t_nama'] ?? '-'} - '
                    '${booking['d_nama'] ?? '-'}',
                  ),
                  subtitle: Text(
                    '${widget.staff ? '${booking['u_nama'] ?? ''}\n' : ''}'
                    '${formatTime(booking['waktu_utc'])}\n'
                    'Status: $status\n'
                    'Bayar: $paymentStatus '
                    '(Rp ${booking['total_idr'] ?? 0})'
                    '${noteText != null && noteText.isNotEmpty ? '\nCatatan: $noteText' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => act(context, booking, value),
                    itemBuilder: (_) => widget.staff
                        ? [
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
                          ]
                        : [
                            if (paymentStatus != 'lunas' &&
                                status != 'rejected')
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
                            const PopupMenuItem(
                              value: 'info',
                              child: Text('Detail'),
                            ),
                          ],
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
