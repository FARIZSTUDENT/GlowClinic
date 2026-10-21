
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _np =
    FlutterLocalNotificationsPlugin();

Future<void> initNotif() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await _np.initialize(settings);

  await _np
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> notify(
  int id,
  String title,
  String body,
  DateTime when,
) async {
  if (!when.isAfter(DateTime.now())) return;

  await _np.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(when, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'glow',
        'GlowClinic',
        channelDescription: 'Pengingat booking dan aftercare treatment',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> syncNotif(Map<String, dynamic> b) async {
  final rawId = b['id'];
  final id = rawId is int ? rawId : int.tryParse('$rawId');

  if (id == null) return;

  final status = '${b['status']}';

  final reminderTomorrow = id * 10 + 1;
  final reminderHour = id * 10 + 2;
  final aftercareDay3 = id * 10 + 3;
  final aftercareDay7 = id * 10 + 4;

  if (status != 'confirmed') {
    await _np.cancel(reminderTomorrow);
    await _np.cancel(reminderHour);
  }

  if (status != 'done') {
    await _np.cancel(aftercareDay3);
    await _np.cancel(aftercareDay7);
  }

  if (status != 'confirmed' && status != 'done') return;

  final waktu = DateTime.tryParse('${b['waktu_utc']}');
  if (waktu == null) return;

  final w = waktu.toLocal();
  final nama = '${b['t_nama'] ?? 'Treatment'}';
  final dokter = '${b['d_nama'] ?? 'dokter'}';

  if (status == 'confirmed') {
    await notify(
      reminderTomorrow,
      'Besok jadwal treatment',
      '$nama dengan $dokter. Hindari skincare aktif 24 jam sebelumnya.',
      DateTime(w.year, w.month, w.day - 1, 9),
    );

    await notify(
      reminderHour,
      '1 jam lagi',
      '$nama dimulai pukul '
          '${w.hour.toString().padLeft(2, '0')}:'
          '${w.minute.toString().padLeft(2, '0')}',
      w.subtract(const Duration(hours: 1)),
    );
  }

  if (status == 'done') {
    await notify(
      aftercareDay3,
      'Aftercare hari ke-3',
      'Pakai sunscreen dan pelembap. Hubungi klinik jika ada keluhan.',
      w.add(const Duration(days: 3)),
    );

    await notify(
      aftercareDay7,
      'Aftercare hari ke-7',
      'Waktunya kontrol. Buat jadwal kontrol di GlowClinic.',
      w.add(const Duration(days: 7)),
    );
  }
}

// ---------- Notifikasi langsung & promo ----------

/// Isi promo (judul, isi). Ganti dengan promo klinik yang berlaku.
const List<List<String>> kPromos = [
  [
    '⚡ Flash Sale GlowClinic',
    'Diskon 20% Facial Medis khusus hari ini. Booking sekarang!',
  ],
  [
    '🎁 Voucher Treatment Pertama',
    'Pakai kode GLOW10 untuk potongan treatment pertamamu.',
  ],
  [
    '✨ Gratis Konsultasi Kulit',
    'Booking treatment hari ini, konsultasi dokter gratis.',
  ],
  [
    '🔥 Paket Acne Care Hemat',
    'Paket 3x perawatan jerawat lebih hemat. Slot terbatas!',
  ],
  [
    '🎰 Putar GlowSpin!',
    'Selesaikan treatment dan menangkan hadiah di GlowSpin.',
  ],
  [
    '🌙 Promo Malam Ini',
    'Diskon 15% Chemical Peeling sampai tengah malam.',
  ],
];

const _promoBase = 900000;

NotificationDetails _details({required bool promo}) => NotificationDetails(
      android: AndroidNotificationDetails(
        promo ? 'promo' : 'glow',
        promo ? 'Promo GlowClinic' : 'GlowClinic',
        channelDescription: promo
            ? 'Promo dan penawaran GlowClinic'
            : 'Pengingat booking dan aftercare treatment',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
    );

/// Menampilkan notifikasi sistem sekarang juga.
Future<void> showNow(
  int id,
  String title,
  String body, {
  bool promo = false,
}) async {
  await _np.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        promo ? 'promo' : 'glow',
        promo ? 'Promo GlowClinic' : 'GlowClinic',
        channelDescription: promo
            ? 'Promo dan penawaran GlowClinic'
            : 'Pengingat booking dan aftercare treatment',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    ),
  );
}

Future<void> cancelPromos() async {
  for (var i = 0; i < 30; i++) {
    await _np.cancel(_promoBase + i);
  }
}

/// Menjadwalkan promo harian (12.00 dan 19.00) untuk 7 hari ke depan.
Future<void> schedulePromos() async {
  await cancelPromos();

  final now = DateTime.now();
  var n = 0;

  for (var d = 0; d < 7; d++) {
    for (final hour in const [12, 19]) {
      final when = DateTime(now.year, now.month, now.day + d, hour);
      if (!when.isAfter(now)) continue;

      final promo = kPromos[(now.day + d * 2 + hour) % kPromos.length];

      await _np.zonedSchedule(
        _promoBase + n,
        promo[0],
        promo[1],
        tz.TZDateTime.from(when, tz.local),
        _details(promo: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      n++;
    }
  }
}
