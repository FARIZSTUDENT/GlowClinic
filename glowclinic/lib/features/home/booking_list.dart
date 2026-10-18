import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/booking/zones.dart';

class BookingList extends StatefulWidget {
  final bool staff;

  const BookingList({super.key, required this.staff});

  @override
  State<BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<BookingList> {
  late Future<List<Map<String, dynamic>>> bookingsFuture;

  @override
  void initState() {
    super.initState();
    bookingsFuture = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final result = await qry(
      'select b.*, '
      't.nama as t_nama, '
      'd.nama as d_nama, '
      'u.nama as u_nama '
      'from bookings b '
      'join treatments t on t.id = b.treatment_id '
      'join doctors d on d.id = b.doctor_id '
      'join users u on u.id = b.user_id '
      '${widget.staff ? '' : 'where b.user_id = ? '}'
      'order by b.waktu_utc desc',
      widget.staff ? [] : [myId],
    );

    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> refreshBookings() async {
    setState(() {
      bookingsFuture = load();
    });

    await bookingsFuture;
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

    if (status == 'done') {
      final noteText = booking['catatan_dokter']?.toString() ?? '';
      final noteHash = sha(noteText);
      final timestamp = DateTime.now().toUtc().toIso8601String();

      await Chain.add('record:${booking['id']}:$noteHash:$timestamp');
    }
  }

  Future<String?> note(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    if (!widget.staff) {
      return null;
    }

    final controller = TextEditingController(
      text: booking['catatan_dokter']?.toString() ?? '',
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
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
          );
        },
      );

      if (result != true || !mounted) {
        return null;
      }

      final text = controller.text.trim();

      await db.update(
        'bookings',
        {'catatan_dokter': text},
        where: 'id = ?',
        whereArgs: [booking['id']],
      );

      booking['catatan_dokter'] = text;

      return text;
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
      if (value == 'catatan') {
        final updatedNote = await note(context, booking);

        if (updatedNote == null) {
          return;
        }

        showMessage('Catatan treatment berhasil disimpan.');
      } else {
        await setStatus(booking, value);

        if (value == 'done') {
          showMessage(
            'Status selesai disimpan dan catatan dikirim ke blockchain.',
          );
        } else {
          showMessage('Status booking diperbarui.');
        }
      }
    } catch (e) {
      showMessage(
        value == 'done'
            ? 'Status mungkin sudah tersimpan, tetapi pencatatan '
                  'blockchain gagal. Periksa kembali sebelum mencoba lagi.'
            : 'Operasi gagal. Periksa koneksi dan coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          bookingsFuture = load();
        });
      }
    }
  }

  String formatBookingTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');

    if (parsed == null) {
      return 'Waktu booking tidak valid';
    }

    return zoneText(parsed.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 8),
                  const Text('Gagal memuat daftar booking.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        bookingsFuture = load();
                      });
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
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
          onRefresh: refreshBookings,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final treatmentName = booking['t_nama']?.toString() ?? 'Layanan';
              final doctorName = booking['d_nama']?.toString() ?? 'Dokter';
              final status = booking['status']?.toString() ?? 'pending';
              final doctorNote = booking['catatan_dokter']?.toString();

              final subtitle = [
                if (widget.staff) 'Pasien: ${booking['u_nama'] ?? '-'}',
                formatBookingTime(booking['waktu_utc']),
                'Status: $status',
                if (doctorNote != null && doctorNote.isNotEmpty)
                  'Catatan: $doctorNote',
              ].join('\n');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('$treatmentName - $doctorName'),
                  subtitle: Text(subtitle),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Aksi booking',
                    onSelected: (value) {
                      act(context, booking, value);
                    },
                    itemBuilder: (_) {
                      if (!widget.staff) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'info',
                            child: Text('Detail'),
                          ),
                        ];
                      }

                      return const [
                        PopupMenuItem<String>(
                          value: 'confirmed',
                          child: Text('Konfirmasi'),
                        ),
                        PopupMenuItem<String>(
                          value: 'rejected',
                          child: Text('Tolak'),
                        ),
                        PopupMenuItem<String>(
                          value: 'checked_in',
                          child: Text('Pasien hadir'),
                        ),
                        PopupMenuItem<String>(
                          value: 'in_treatment',
                          child: Text('Sedang treatment'),
                        ),
                        PopupMenuItem<String>(
                          value: 'catatan',
                          child: Text('Rekam treatment'),
                        ),
                        PopupMenuItem<String>(
                          value: 'done',
                          child: Text('Selesai'),
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
