import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _np = FlutterLocalNotificationsPlugin();

Future<void> initNotif() async {
  // Inisialisasi zona waktu Indonesia (WIB).
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await _np.initialize(settings: settings);

  await _np
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

Future<void> notify(int id, String title, String body, DateTime when) async {
  if (!when.isAfter(DateTime.now())) return;

  await _np.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(when, tz.local),
    notificationDetails: const NotificationDetails(
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
  final id = b['id'] as int;
  final status = '${b['status']}';

  final reminderTomorrow = id * 10 + 1;
  final reminderHour = id * 10 + 2;
  final aftercareDay3 = id * 10 + 3;
  final aftercareDay7 = id * 10 + 4;

  if (status != 'confirmed') {
    await _np.cancel(id: reminderTomorrow);
    await _np.cancel(id: reminderHour);
  }

  if (status != 'done') {
    await _np.cancel(id: aftercareDay3);
    await _np.cancel(id: aftercareDay7);
  }

  if (status != 'confirmed' && status != 'done') {
    return;
  }

  final w = DateTime.parse('${b['waktu_utc']}').toLocal();
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
