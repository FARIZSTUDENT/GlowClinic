import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/payment/payment.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';
import 'package:glowclinic/features/spin/glowspin.dart';
import 'package:glowclinic/features/feedback/feedback.dart';
import 'package:glowclinic/features/notif/notif.dart';

class BookingList extends StatefulWidget {
  const BookingList({super.key, required this.staff});

  final bool staff;

  @override
  State<BookingList> createState() => _BookingListState();
}

class _BookingListState extends State<BookingList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final bookings = await qry(
      'SELECT b.*, t.nama AS t_nama, d.nama AS d_nama, '
      'u.nama AS u_nama '
      'FROM bookings b '
      'JOIN treatments t ON t.id = b.treatment_id '
      'JOIN doctors d ON d.id = b.doctor_id '
      'JOIN users u ON u.id = b.user_id '
      '${widget.staff ? '' : 'WHERE b.user_id = ? '}'
      'ORDER BY b.waktu_utc DESC',
      widget.staff ? [] : [myId],
    );

    if (!widget.staff) {
      for (final booking in bookings) {
        try {
          await syncNotif(booking);
        } catch (e) {
          debugPrint('Gagal menyinkronkan notifikasi: $e');
        }
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

  Future<void> setStatus(Map<String, dynamic> booking, String status) async {
    if (!widget.staff) return;

    final id = booking['id'];
    final oldStatus = booking['status'];

    if (oldStatus == status) return;

    try {
      await db.update(
        'bookings',
        {'status': status},
        where: 'id = ? AND status = ?',
        whereArgs: [id, oldStatus],
      );

      if (status == 'done') {
        try {
          await Chain.add('booking:$id:Treatment selesai');
        } catch (e) {
          debugPrint('Gagal mencatat blockchain: $e');
        }
      }

      if (!mounted) return;

      snack(context, 'Status booking berhasil diperbarui');
      reload();
    } catch (e) {
      debugPrint('Gagal memperbarui status booking: $e');

      if (!mounted) return;

      snack(context, 'Gagal memperbarui status booking');
    }
  }

  Future<void> note(
    BuildContext dialogContext,
    Map<String, dynamic> booking,
  ) async {
    final controller = TextEditingController(
      text: (booking['catatan_dokter'] ?? '').toString(),
    );

    try {
      final result = await showDialog<String>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: const Text('Catatan Treatment'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Masukkan catatan treatment...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      await db.update(
        'bookings',
        {'catatan_dokter': result},
        where: 'id = ?',
        whereArgs: [booking['id']],
      );

      if (!mounted) return;

      snack(context, 'Catatan treatment disimpan');
      reload();
    } catch (e) {
      debugPrint('Gagal menyimpan catatan treatment: $e');

      if (!mounted) return;

      snack(context, 'Gagal menyimpan catatan treatment');
    } finally {
      controller.dispose();
    }
  }

  Future<void> act(
    BuildContext actionContext,
    Map<String, dynamic> booking,
    String action,
  ) async {
    switch (action) {
      case 'bayar':
        await payQris(actionContext, booking);
        break;

      case 'lunas':
        await payQris(actionContext, booking);
        break;

      case 'checkin':
        await doCheckIn(actionContext, booking);
        break;

      case 'foto':
        await Navigator.push(
          actionContext,
          MaterialPageRoute(builder: (_) => PhotoScreen(booking)),
        );
        break;

      case 'spin':
        await Navigator.push(
          actionContext,
          MaterialPageRoute(builder: (_) => SpinScreen(booking)),
        );
        break;

      case 'ulasan':
        await Navigator.push(
          actionContext,
          MaterialPageRoute(builder: (_) => FeedbackScreen(booking)),
        );
        break;

      case 'catatan':
        await note(actionContext, booking);
        break;

      case 'confirm':
        await setStatus(booking, 'confirmed');
        break;

      case 'done':
        await setStatus(booking, 'done');
        break;

      case 'cancel':
        await setStatus(booking, 'cancelled');
        break;

      default:
        return;
    }

    if (!mounted) return;

    reload();
  }

  List<PopupMenuEntry<String>> menuItems(Map<String, dynamic> booking) {
    final status = booking['status']?.toString() ?? '';

    if (widget.staff) {
      return [
        const PopupMenuItem(
          value: 'confirm',
          child: Text('Konfirmasi booking'),
        ),
        const PopupMenuItem(value: 'done', child: Text('Tandai selesai')),
        const PopupMenuItem(value: 'cancel', child: Text('Batalkan booking')),
        const PopupMenuItem(value: 'catatan', child: Text('Catatan treatment')),
      ];
    }

    return [
      if (status == 'pending')
        const PopupMenuItem(value: 'bayar', child: Text('Pembayaran')),
      if (status == 'confirmed')
        const PopupMenuItem(value: 'checkin', child: Text('Check-in')),
      if (status == 'done') ...[
        const PopupMenuItem(value: 'foto', child: Text('Jurnal kulit')),
        const PopupMenuItem(value: 'spin', child: Text('GlowSpin')),
        const PopupMenuItem(value: 'ulasan', child: Text('Beri ulasan')),
      ],
    ];
  }

  Color statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'done':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'done':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal memuat daftar booking.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              reload();
              try {
                await _future;
              } catch (_) {
                // Error ditampilkan oleh FutureBuilder.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Center(child: Text('Belum ada booking.')),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            reload();
            try {
              await _future;
            } catch (_) {
              // Error ditampilkan oleh FutureBuilder.
            }
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final status = booking['status']?.toString() ?? 'pending';
              final color = statusColor(status);
              final waktu = booking['waktu_utc']?.toString() ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(child: Icon(Icons.spa_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking['t_nama']?.toString() ?? 'Treatment',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text('Dokter: ${booking['d_nama'] ?? '-'}'),
                                if (widget.staff)
                                  Text('Pasien: ${booking['u_nama'] ?? '-'}'),
                                const SizedBox(height: 4),
                                Text('Jadwal: $waktu'),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Aksi booking',
                            onSelected: (action) {
                              act(context, booking, action);
                            },
                            itemBuilder: (_) => menuItems(booking),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            avatar: Icon(Icons.circle, size: 10, color: color),
                            label: Text(statusLabel(status)),
                          ),
                          if (booking['catatan_dokter'] != null &&
                              booking['catatan_dokter']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                            const Chip(
                              avatar: Icon(Icons.notes, size: 16),
                              label: Text('Ada catatan dokter'),
                            ),
                        ],
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
