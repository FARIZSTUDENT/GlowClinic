import 'package:timezone/timezone.dart' as tz;

/// Konversi 4 zona waktu
const zones = {
  'WIB': 'Asia/Jakarta',
  'WITA': 'Asia/Makassar',
  'WIT': 'Asia/Jayapura',
  'London': 'Europe/London',
};
String zoneText(DateTime utc) => zones.entries
    .map((e) {
      final t = tz.TZDateTime.from(utc, tz.getLocation(e.value));
      return '${e.key} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    })
    .join(' | ');
