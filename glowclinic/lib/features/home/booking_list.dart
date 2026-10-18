import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/lbs/lbs.dart';

class BookingList extends StatefulWidget {
  final bool staff;

  const BookingList({super.key, required this.staff});

  @override
  State<BookingList> createState() => _BL();
}

class _BL extends State<BookingList> {
  late Future<List<Map<String, dynamic>>> bookingsFuture;

  @override
  void initState() {
    super.initState();
    bookingsFuture = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final result = await qry(
      'select b.*, '
      't.nama t_nama, '
      'd.nama d_nama, '
      'u.nama u_nama '
      'from bookings b '
      'join treatments t on t.id = b.treatment_id '
      'join doctors d on d.id = b.doctor_id '
      'join users u on u.id = b.user_id '
      '${widget.staff ? '' : 'where b.user_id=$myId '}'
      'order by b.waktu_utc desc',
    );

    return List<Map<String, dynamic>>.from(result);
  }

  void reload() {
    if (!mounted) {
      return;
    }

    setState(() {
      bookingsFuture = load();
    });
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> setStatus(Map<String, dynamic> booking, String status) async {
    if (!widget.staff) {
      return;
    }

    await db.update(
      'bookings',
      {'status': status},
      where: 'id = ?',
      whereArgs: [booking['id']],
    );

    booking['status'] = status;

    if (status == 'done') {
      final noteText = booking['catatan_dokter']?.toString() ?? '';
      final noteHash = sha(noteText);
      final timestamp = DateTime.now().toUtc().toIso8601String();

      await Chain.add('record:${booking['id']}:$noteHash:$timestamp');
    }
  }

  Future<void> note(BuildContext context, Map<String, dynamic> booking) async {
    if (!widget.staff) {
      return;
    }

    final controller = TextEditingController(
      text: booking['catatan_dokter']?.toString() ?? '',
    );

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rekam treatment'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tindakan, produk, kondisi kulit',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) {
        return;
      }

      final text = controller.text.trim();

      await db.update(
        'bookings',
        {'catatan_dokter': text},
        where: 'id = ?',
        whereArgs: [booking['id']],
      );

      booking['catatan_dokter'] = text;

      showMessage('Catatan treatment berhasil disimpan.');
    } finally {
      controller.dispose();
    }
  }

  Future<void> act(
    BuildContext context,
    Map<String, dynamic> booking,
    String value,
  ) async {
    if (value == 'info') {
      showMessage('Status booking: ${booking['status'] ?? 'pending'}');
      return;
    }

    try {
      if (value == 'checkin') {
        if (booking['status'] != 'confirmed') {
          showMessage('Check-in hanya tersedia untuk booking terkonfirmasi.');
          return;
        }

        await doCheckIn(context, booking);
      } else if (value == 'catatan') {
        await note(context, booking);
      } else {
        await setStatus(booking, value);
      }
    } catch (e) {
      showMessage('Operasi gagal. Periksa koneksi dan status booking.');
    } finally {
      reload();
    }
  }

  String bookingTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) {
      return 'Waktu booking tidak valid';
    }

    return zoneText(date.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gagal memuat daftar booking.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: reload,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? <Map<String, dynamic>>[];

        if (bookings.isEmpty) {
          return const Center(child: Text('Belum ada booking'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            final future = load();

            setState(() {
              bookingsFuture = future;
            });

            await future;
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final status = booking['status']?.toString() ?? 'pending';
              final noteText = booking['catatan_dokter']?.toString();

              final subtitle = [
                if (widget.staff) 'Pasien: ${booking['u_nama'] ?? '-'}',
                bookingTime(booking['waktu_utc']),
                'Status: $status',
                if (noteText != null && noteText.isNotEmpty)
                  'Catatan: $noteText',
              ].join('\n');

              return Card(
                child: ListTile(
                  title: Text(
                    '${booking['t_nama'] ?? 'Layanan'} - '
                    '${booking['d_nama'] ?? 'Dokter'}',
                  ),
                  subtitle: Text(subtitle),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Aksi booking',
                    onSelected: (value) {
                      act(context, booking, value);
                    },
                    itemBuilder: (_) {
                      if (widget.staff) {
                        return const [
                          PopupMenuItem(
                            value: 'confirmed',
                            child: Text('confirmed'),
                          ),
                          PopupMenuItem(
                            value: 'rejected',
                            child: Text('rejected'),
                          ),
                          PopupMenuItem(
                            value: 'checked_in',
                            child: Text('checked_in'),
                          ),
                          PopupMenuItem(
                            value: 'in_treatment',
                            child: Text('in_treatment'),
                          ),
                          PopupMenuItem(value: 'done', child: Text('done')),
                          PopupMenuItem(
                            value: 'catatan',
                            child: Text('Rekam treatment'),
                          ),
                        ];
                      }

                      return [
                        if (status == 'confirmed')
                          const PopupMenuItem(
                            value: 'checkin',
                            child: Text('Check-in'),
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
