import 'dart:async';

import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/notif.dart';

const _staffRoles = "'staf','staff','admin'";

/// Format tanggal/jam lokal dari string ISO (UTC).
String fmtDateTime(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '-';

  String two(int v) => v.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Menyimpan notifikasi ke inbox. Notifikasi sistem muncul otomatis
/// (lihat [startNotifWatcher]) saat penerimanya sedang login di perangkat.
///
/// Tentukan penerima dengan [userId], [toStaff], atau [toPatients].
Future<void> pushNotif({
  int? userId,
  bool toStaff = false,
  bool toPatients = false,
  required String judul,
  required String isi,
  String tipe = 'info',
  int? bookingId,
}) async {
  try {
    final ids = <int>{};

    if (userId != null) ids.add(userId);

    if (toStaff) {
      final rows = await qry(
        'select id from users where lower(trim(role)) in ($_staffRoles)',
      );
      ids.addAll(rows.map((r) => r['id'] as int));
    }

    if (toPatients) {
      final rows = await qry(
        'select id from users where lower(trim(role)) not in ($_staffRoles)',
      );
      ids.addAll(rows.map((r) => r['id'] as int));
    }

    final now = DateTime.now().toUtc().toIso8601String();

    for (final id in ids) {
      await db.insert('notifications', {
        'user_id': id,
        'judul': judul,
        'isi': isi,
        'tipe': tipe,
        'booking_id': bookingId,
        'dibaca': 0,
        'shown': 0,
        'waktu_utc': now,
      });
    }

    notifTick.value++;
  } catch (e) {
    debugPrint('Gagal menyimpan notifikasi: $e');
  }
}

// ---------- Pengantar notifikasi sistem ----------

Timer? _watch;
bool _delivering = false;

/// Memeriksa inbox secara berkala dan memunculkan notifikasi sistem
/// untuk akun yang sedang login.
void startNotifWatcher() {
  _watch?.cancel();
  deliverPending();
  _watch = Timer.periodic(
    const Duration(seconds: 4),
    (_) => deliverPending(),
  );
}

void stopNotifWatcher() {
  _watch?.cancel();
  _watch = null;
}

Future<void> deliverPending() async {
  if (_delivering || myId == null) return;

  _delivering = true;

  try {
    final rows = await qry(
      'select * from notifications where user_id = ? and shown = 0 '
      'order by id',
      [myId],
    );

    if (rows.isEmpty) return;

    for (final r in rows) {
      try {
        await showNow(
          1000000 + (r['id'] as int),
          '${r['judul']}',
          '${r['isi']}',
          promo: r['tipe'] == 'promo',
        );
      } catch (e) {
        debugPrint('Gagal menampilkan notifikasi: $e');
      }

      await db.update(
        'notifications',
        {'shown': 1},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }

    notifTick.value++;
  } catch (e) {
    debugPrint('Gagal mengantar notifikasi: $e');
  } finally {
    _delivering = false;
  }
}

// ---------- Promo ----------

/// Untuk pasien: jadwalkan promo harian dan masukkan promo hari ini
/// ke inbox (satu kali per hari).
Future<void> setupPatientPromos() async {
  final id = myId;
  if (id == null) return;

  try {
    await schedulePromos();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'promo_day_$id';

    if (await store.read(key: key) == today) return;

    await store.write(key: key, value: today);

    final promo = kPromos[DateTime.now().day % kPromos.length];

    await pushNotif(
      userId: id,
      judul: promo[0],
      isi: promo[1],
      tipe: 'promo',
    );
  } catch (e) {
    debugPrint('Gagal menyiapkan promo: $e');
  }
}

/// Dialog staf untuk mengirim promo ke semua pasien.
Future<void> sendPromoDialog(BuildContext context) async {
  final title = TextEditingController();
  final body = TextEditingController();

  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kirim promo ke pasien'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Judul promo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Isi promo',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      if (context.mounted) snack(context, 'Judul dan isi promo wajib diisi');
      return;
    }

    await pushNotif(
      toPatients: true,
      judul: title.text.trim(),
      isi: body.text.trim(),
      tipe: 'promo',
    );

    if (context.mounted) snack(context, 'Promo dikirim ke semua pasien');
  } finally {
    title.dispose();
    body.dispose();
  }
}

// ---------- UI ----------

/// Ikon lonceng dengan badge jumlah notifikasi belum dibaca.
class NotifBell extends StatefulWidget {
  const NotifBell({super.key});

  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  int unread = 0;

  @override
  void initState() {
    super.initState();
    refresh();
    notifTick.addListener(refresh);
  }

  @override
  void dispose() {
    notifTick.removeListener(refresh);
    super.dispose();
  }

  Future<void> refresh() async {
    if (myId == null) return;

    try {
      final r = await qry(
        'select count(*) as c from notifications '
        'where user_id = ? and dibaca = 0',
        [myId],
      );

      if (!mounted) return;

      setState(() => unread = (r.first['c'] as int?) ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifikasi',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotifScreen()),
        );
        refresh();
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class NotifScreen extends StatefulWidget {
  const NotifScreen({super.key});

  @override
  State<NotifScreen> createState() => _NotifScreenState();
}

class _NotifScreenState extends State<NotifScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    notifTick.addListener(_reload);
  }

  @override
  void dispose() {
    notifTick.removeListener(_reload);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() => qry(
        'select * from notifications where user_id = ? '
        'order by id desc limit 100',
        [myId],
      );

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['dibaca'] == 1) return;

    await db.update(
      'notifications',
      {'dibaca': 1},
      where: 'id = ?',
      whereArgs: [n['id']],
    );

    notifTick.value++;
  }

  Future<void> _markAll() async {
    await db.update(
      'notifications',
      {'dibaca': 1},
      where: 'user_id = ?',
      whereArgs: [myId],
    );

    notifTick.value++;
  }

  IconData _icon(String? tipe) {
    switch (tipe) {
      case 'promo':
        return Icons.local_offer_rounded;
      case 'bayar':
        return Icons.payments_rounded;
      case 'booking':
        return Icons.event_available_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _color(String? tipe) {
    switch (tipe) {
      case 'promo':
        return Colors.orange;
      case 'bayar':
        return Colors.green;
      case 'booking':
        return const Color(0xFFD85F89);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: _markAll,
            child: const Text('Tandai dibaca'),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('Belum ada notifikasi.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final unread = n['dibaca'] != 1;
              final tipe = n['tipe']?.toString();

              return ListTile(
                tileColor: unread ? const Color(0x14D85F89) : null,
                leading: CircleAvatar(
                  backgroundColor: _color(tipe).withValues(alpha: 0.15),
                  child: Icon(_icon(tipe), color: _color(tipe)),
                ),
                title: Text(
                  '${n['judul']}',
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${n['isi']}\n${fmtDateTime(n['waktu_utc'])}'),
                ),
                isThreeLine: true,
                onTap: () => _markRead(n),
              );
            },
          );
        },
      ),
    );
  }
}
