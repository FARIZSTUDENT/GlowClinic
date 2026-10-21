import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/blockchain/chain.dart';
import 'package:glowclinic/features/payment/payment.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';
import 'package:glowclinic/features/spin/glowspin.dart';
import 'package:glowclinic/features/feedback/feedback.dart';
import 'package:glowclinic/features/notif/notif.dart';
import 'package:glowclinic/features/notif/inbox.dart';

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
    bookingRefresh.addListener(reload);
  }

  @override
  void dispose() {
    bookingRefresh.removeListener(reload);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final bookings = await qry(
      'SELECT b.*, '
      "COALESCE(b.treatment_nama, t.nama, 'Treatment') AS t_nama, "
      'd.nama AS d_nama, u.nama AS u_nama '
      'FROM bookings b '
      'LEFT JOIN treatments t ON t.id = b.treatment_id '
      'LEFT JOIN doctors d ON d.id = b.doctor_id '
      'LEFT JOIN users u ON u.id = b.user_id '
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

  /// Alur status booking: Menunggu -> Dikonfirmasi -> Check-in -> Selesai.
  static const _flow = {
    'pending': ['confirmed', 'cancelled'],
    'confirmed': ['checked_in', 'cancelled'],
    'checked_in': ['done', 'cancelled'],
  };

  Future<void> _notifyPatient(Map<String, dynamic> b, String status) async {
    final what = '${b['t_nama'] ?? 'treatment'}';
    final uid = b['user_id'] as int?;
    final bid = b['id'] as int?;

    switch (status) {
      case 'confirmed':
        await pushNotif(
          userId: uid,
          judul: 'Booking dikonfirmasi ✅',
          isi: '$what dengan ${b['d_nama'] ?? 'dokter'} pada '
              '${fmtDateTime(b['waktu_utc'])}. Tekan Check-in saat tiba '
              'di klinik.',
          tipe: 'booking',
          bookingId: bid,
        );
      case 'cancelled':
        await pushNotif(
          userId: uid,
          judul: 'Booking dibatalkan ❌',
          isi: 'Booking $what tidak dapat diproses. '
              'Silakan buat booking baru.',
          tipe: 'booking',
          bookingId: bid,
        );
      case 'checked_in':
        await pushNotif(
          userId: uid,
          judul: 'Check-in dicatat staf 📍',
          isi: 'Silakan lanjutkan pembayaran QRIS untuk $what.',
          tipe: 'bayar',
          bookingId: bid,
        );
      case 'done':
        await pushNotif(
          userId: uid,
          judul: 'Treatment selesai 🎉',
          isi: '$what telah selesai. Isi jurnal kulit, putar GlowSpin, '
              'dan beri ulasan ya!',
          tipe: 'booking',
          bookingId: bid,
        );
    }
  }

  Future<void> setStatus(Map<String, dynamic> booking, String status) async {
    if (!widget.staff) return;

    final id = booking['id'];
    final oldStatus = '${booking['status']}';

    if (oldStatus == status) return;

    if (!(_flow[oldStatus] ?? const <String>[]).contains(status)) {
      snack(context, 'Langkah ini tidak valid untuk status saat ini.');
      return;
    }

    if (status == 'done' && booking['status_bayar'] != 'lunas') {
      snack(
        context,
        'Pembayaran harus lunas sebelum treatment ditandai selesai.',
      );
      return;
    }

    try {
      final updated = await db.update(
        'bookings',
        {'status': status},
        where: 'id = ? AND status = ?',
        whereArgs: [id, oldStatus],
      );

      if (updated == 0) {
        if (!mounted) return;
        snack(context, 'Status booking sudah berubah. Daftar dimuat ulang.');
        reload();
        return;
      }

      if (status == 'done') {
        try {
          await Chain.add('booking:$id:Treatment selesai');
        } catch (e) {
          debugPrint('Gagal mencatat blockchain: $e');
        }
      }

      await _notifyPatient(booking, status);

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

  bool _acting = false;

  Future<void> act(
    BuildContext actionContext,
    Map<String, dynamic> booking,
    String action,
  ) async {
    if (_acting) return;
    _acting = true;

    try {
      switch (action) {
        case 'bayar':
          await payQris(actionContext, booking);
          break;

        case 'checkin':
          {
            final ok = await doCheckIn(actionContext, booking);

            // Setelah check-in, pasien langsung diarahkan untuk membayar.
            if (ok && actionContext.mounted) {
              await payQris(actionContext, {...booking, 'status': 'checked_in'});
            }
          }
          break;

        case 'checkin_manual':
          await setStatus(booking, 'checked_in');
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

        case 'verifikasi':
          await confirmPaid(actionContext, booking);
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
    } finally {
      _acting = false;
    }

    if (!mounted) return;

    reload();
  }

  /// Menu titik tiga (khusus staf): aksi sekunder.
  List<PopupMenuEntry<String>> menuItems(Map<String, dynamic> booking) {
    if (!widget.staff) return [];

    final status = booking['status']?.toString() ?? '';

    return [
      if (status != 'cancelled')
        const PopupMenuItem(value: 'catatan', child: Text('Catatan treatment')),
      if (status == 'pending' || status == 'confirmed' || status == 'checked_in')
        const PopupMenuItem(value: 'cancel', child: Text('Batalkan booking')),
    ];
  }

  /// Petunjuk langkah berikutnya sesuai peran dan status.
  String? nextStep(Map<String, dynamic> b, String status) {
    final pay = '${b['status_bayar']}';

    if (widget.staff) {
      switch (status) {
        case 'pending':
          return 'Periksa booking, lalu Acc atau Tolak.';
        case 'confirmed':
          return 'Menunggu pasien check-in di klinik.';
        case 'checked_in':
          if (pay == 'lunas') {
            return 'Pembayaran lunas. Lakukan treatment, isi catatan, '
                'lalu tandai selesai.';
          }
          if (pay == 'menunggu_verifikasi') {
            return 'Pasien sudah membayar. Verifikasi pembayaran.';
          }
          return 'Menunggu pasien menyelesaikan pembayaran.';
        case 'done':
          return 'Treatment selesai.';
      }
      return null;
    }

    switch (status) {
      case 'pending':
        return 'Menunggu konfirmasi staf klinik.';
      case 'confirmed':
        return 'Datang ke klinik lalu tekan Check-in '
            '(maks. 100 m dari cabang).';
      case 'checked_in':
        if (pay == 'lunas') {
          return 'Pembayaran lunas. Treatment sedang berlangsung.';
        }
        if (pay == 'menunggu_verifikasi') {
          return 'Pembayaran sedang diverifikasi staf.';
        }
        return 'Silakan lakukan pembayaran QRIS.';
      case 'done':
        return 'Treatment selesai. Isi jurnal kulit, putar GlowSpin, '
            'dan beri ulasan.';
    }

    return null;
  }

  /// Tombol aksi utama: (label, ikon, kode aksi, tombol utama?).
  List<(String, IconData, String, bool)> actionsFor(
    Map<String, dynamic> b,
    String status,
  ) {
    final pay = '${b['status_bayar']}';

    if (widget.staff) {
      switch (status) {
        case 'pending':
          return [
            ('Acc', Icons.check_rounded, 'confirm', true),
            ('Tolak', Icons.close_rounded, 'cancel', false),
          ];
        case 'confirmed':
          return [
            ('Check-in manual', Icons.how_to_reg_outlined, 'checkin_manual', true),
            ('Batalkan', Icons.close_rounded, 'cancel', false),
          ];
        case 'checked_in':
          return [
            if (pay == 'menunggu_verifikasi')
              ('Verifikasi pembayaran', Icons.verified_outlined, 'verifikasi', true),
            if (pay == 'lunas')
              ('Tandai selesai', Icons.task_alt_rounded, 'done', true),
            ('Catatan', Icons.edit_note_rounded, 'catatan', false),
          ];
      }
      return [];
    }

    switch (status) {
      case 'confirmed':
        return [('Check-in', Icons.location_on_outlined, 'checkin', true)];
      case 'checked_in':
        if (pay == 'lunas') return [];
        return [
          pay == 'menunggu_verifikasi'
              ? ('Lihat QRIS', Icons.qr_code_2_rounded, 'bayar', false)
              : ('Bayar sekarang', Icons.qr_code_2_rounded, 'bayar', true),
        ];
      case 'done':
        return [
          ('Jurnal kulit', Icons.photo_camera_outlined, 'foto', false),
          if (pay == 'lunas')
            ('GlowSpin', Icons.casino_outlined, 'spin', false),
          ('Ulasan', Icons.rate_review_outlined, 'ulasan', false),
        ];
    }

    return [];
  }

  List<Widget> hintAndActions(
    BuildContext context,
    Map<String, dynamic> booking,
    String status,
  ) {
    final hint = nextStep(booking, status);
    final actions = actionsFor(booking, status);

    return [
      if (hint != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFFD85F89),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(hint, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in actions)
              a.$4
                  ? FilledButton.icon(
                      onPressed: () => act(context, booking, a.$3),
                      icon: Icon(a.$2, size: 18),
                      label: Text(a.$1),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => act(context, booking, a.$3),
                      icon: Icon(a.$2, size: 18),
                      label: Text(a.$1),
                    ),
          ],
        ),
      ],
    ];
  }

  Color statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'checked_in':
        return Colors.teal;
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
      case 'checked_in':
        return 'Check-in';
      case 'done':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String payLabel(String? v) {
    switch (v) {
      case 'lunas':
        return 'Lunas';
      case 'menunggu_verifikasi':
        return 'Menunggu verifikasi bayar';
      default:
        return 'Belum bayar';
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
              final waktu = fmtDateTime(booking['waktu_utc']);

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
                          if (menuItems(booking).isNotEmpty)
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
                          Chip(
                            avatar: const Icon(Icons.payments_outlined, size: 16),
                            label: Text(payLabel(booking['status_bayar']?.toString())),
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
                      ...hintAndActions(context, booking, status),
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
