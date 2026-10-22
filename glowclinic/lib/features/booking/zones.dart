import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tz;

/// Model data zona waktu yang didukung aplikasi GlowClinic.
class TimeZoneInfo {
  final String code; // 'WIB', 'WITA', 'WIT', 'London'
  final String locationName; // IANA Identifier: 'Asia/Jakarta', dll.
  final String label; // Nama lengkap & keterangan UTC
  final String region; // Daerah / Kota
  final String defaultOffsetLabel; // e.g. 'UTC+7'

  const TimeZoneInfo({
    required this.code,
    required this.locationName,
    required this.label,
    required this.region,
    required this.defaultOffsetLabel,
  });

  /// Mendapatkan lokasi tz dari database IANA
  tz.Location get location => tz.getLocation(locationName);
}

/// Daftar 4 zona waktu sesuai ketentuan tugas.
const Map<String, TimeZoneInfo> supportedTimeZones = {
  'WIB': TimeZoneInfo(
    code: 'WIB',
    locationName: 'Asia/Jakarta',
    label: 'WIB — Waktu Indonesia Barat (UTC+7)',
    region: 'Asia/Jakarta',
    defaultOffsetLabel: 'UTC+7',
  ),
  'WITA': TimeZoneInfo(
    code: 'WITA',
    locationName: 'Asia/Makassar',
    label: 'WITA — Waktu Indonesia Tengah (UTC+8)',
    region: 'Asia/Makassar',
    defaultOffsetLabel: 'UTC+8',
  ),
  'WIT': TimeZoneInfo(
    code: 'WIT',
    locationName: 'Asia/Jayapura',
    label: 'WIT — Waktu Indonesia Timur (UTC+9)',
    region: 'Asia/Jayapura',
    defaultOffsetLabel: 'UTC+9',
  ),
  'London': TimeZoneInfo(
    code: 'London',
    locationName: 'Europe/London',
    label: 'London — Europe/London (GMT/BST)',
    region: 'Europe/London',
    defaultOffsetLabel: 'UTC+0 / UTC+1 (DST)',
  ),
};

/// Backward-compatible map nama zona -> IANA location
const zones = {
  'WIB': 'Asia/Jakarta',
  'WITA': 'Asia/Makassar',
  'WIT': 'Asia/Jayapura',
  'London': 'Europe/London',
};

/// Hasil komputasi konversi waktu antar zona.
class TimeConversionResult {
  final String fromZone;
  final String toZone;
  final DateTime fromDate;
  final int fromHour;
  final int fromMinute;
  final tz.TZDateTime sourceTz;
  final tz.TZDateTime targetTz;
  final int dayDifference; // -1 (kemarin), 0 (hari sama), +1 (besok), dst.
  final bool isDateChanged;
  final bool isLondonDst;
  final int offsetDifferenceHours;
  final int offsetDifferenceMinutes;

  TimeConversionResult({
    required this.fromZone,
    required this.toZone,
    required this.fromDate,
    required this.fromHour,
    required this.fromMinute,
    required this.sourceTz,
    required this.targetTz,
    required this.dayDifference,
    required this.isDateChanged,
    required this.isLondonDst,
    required this.offsetDifferenceHours,
    required this.offsetDifferenceMinutes,
  });

  /// Format jam 24 jam untuk hasil: "HH:mm"
  String get formattedTime =>
      '${targetTz.hour.toString().padLeft(2, '0')}:${targetTz.minute.toString().padLeft(2, '0')}';

  /// Format waktu dengan kode zona tujuan: "HH:mm WITA"
  String get formattedTimeWithZone => '$formattedTime $toZone';

  /// Format tanggal hasil konversi (Indonesia)
  String get formattedTargetDate {
    return TimeZoneService.formatIndonesianDate(
      DateTime(targetTz.year, targetTz.month, targetTz.day),
    );
  }

  /// Format tanggal asal konversi (Indonesia)
  String get formattedSourceDate {
    return TimeZoneService.formatIndonesianDate(
      DateTime(sourceTz.year, sourceTz.month, sourceTz.day),
    );
  }

  /// Keterangan status pergantian tanggal
  String? get dateChangeNotice {
    if (dayDifference == 1) {
      return '+1 Hari (Hari Berikutnya)';
    } else if (dayDifference > 1) {
      return '+$dayDifference Hari ke depan';
    } else if (dayDifference == -1) {
      return '-1 Hari (Hari Sebelumnya)';
    } else if (dayDifference < -1) {
      return '$dayDifference Hari sebelumnya';
    }
    return null;
  }

  /// Keterangan selisih waktu antar zona
  String get differenceDescription {
    if (fromZone == toZone) {
      return 'Zona waktu sama';
    }

    final totalMin = offsetDifferenceMinutes;
    final hours = totalMin ~/ 60;
    final mins = totalMin.abs() % 60;

    String timeStr = '${hours.abs()} jam';
    if (mins > 0) timeStr += ' $mins menit';

    if (totalMin > 0) {
      return '$toZone lebih cepat $timeStr dari $fromZone';
    } else {
      return '$toZone lebih lambat $timeStr dari $fromZone';
    }
  }

  /// Keterangan Daylight Saving Time jika melibatkan London
  String? get londonDstStatus {
    if (fromZone != 'London' && toZone != 'London') return null;

    final londonTz = fromZone == 'London' ? sourceTz : targetTz;
    final offsetHours = londonTz.timeZoneOffset.inHours;

    if (offsetHours == 1) {
      return 'London sedang Daylight Saving Time (BST, UTC+1)';
    } else {
      return 'London menggunakan waktu standar (GMT, UTC+0)';
    }
  }
}

/// Service logika konversi waktu terpusat.
class TimeZoneService {
  static bool _initialized = false;

  /// Pastikan database zona waktu siap digunakan
  static void ensureInitialized() {
    if (!_initialized) {
      tzd.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Mendapatkan TimeZoneInfo berdasarkan kode ('WIB', 'WITA', 'WIT', 'London')
  static TimeZoneInfo getInfo(String code) {
    ensureInitialized();
    final info = supportedTimeZones[code];
    if (info == null) {
      throw ArgumentError('Zona waktu tidak didukung: $code');
    }
    return info;
  }

  /// Mengonversi waktu dari zona asal ke zona tujuan
  static TimeConversionResult convert({
    required String fromZone,
    required String toZone,
    required DateTime date,
    required int hour,
    required int minute,
  }) {
    ensureInitialized();

    final fromInfo = getInfo(fromZone);
    final toInfo = getInfo(toZone);

    // Bentuk objek TZDateTime di zona asal
    final sourceTz = tz.TZDateTime(
      fromInfo.location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    // Konversi ke zona tujuan
    final targetTz = tz.TZDateTime.from(sourceTz, toInfo.location);

    // Hitung pergantian tanggal
    final sourceDateOnly = DateTime(sourceTz.year, sourceTz.month, sourceTz.day);
    final targetDateOnly = DateTime(targetTz.year, targetTz.month, targetTz.day);
    final dayDiff = targetDateOnly.difference(sourceDateOnly).inDays;

    // Hitung London DST jika relevan
    final londonLoc = tz.getLocation('Europe/London');
    final londonAtThatTime = tz.TZDateTime.from(sourceTz, londonLoc);
    final isDst = londonAtThatTime.timeZoneOffset.inHours == 1;

    // Selisih offset antara target dan source
    final offsetDiffMinutes =
        targetTz.timeZoneOffset.inMinutes - sourceTz.timeZoneOffset.inMinutes;

    return TimeConversionResult(
      fromZone: fromZone,
      toZone: toZone,
      fromDate: date,
      fromHour: hour,
      fromMinute: minute,
      sourceTz: sourceTz,
      targetTz: targetTz,
      dayDifference: dayDiff,
      isDateChanged: dayDiff != 0,
      isLondonDst: isDst,
      offsetDifferenceHours: offsetDiffMinutes ~/ 60,
      offsetDifferenceMinutes: offsetDiffMinutes,
    );
  }

  /// Mengonversi waktu asal ke semua 4 zona waktu sekaligus
  static Map<String, TimeConversionResult> convertToAllZones({
    required String fromZone,
    required DateTime date,
    required int hour,
    required int minute,
  }) {
    final results = <String, TimeConversionResult>{};
    for (final zoneKey in supportedTimeZones.keys) {
      results[zoneKey] = convert(
        fromZone: fromZone,
        toZone: zoneKey,
        date: date,
        hour: hour,
        minute: minute,
      );
    }
    return results;
  }

  /// Konversi waktu lokal terpilih (dengan zona asal yang ditentukan pengguna) ke DateTime UTC
  static DateTime toUtc({
    required DateTime date,
    required int hour,
    required int minute,
    required String fromZone,
  }) {
    ensureInitialized();
    final fromInfo = getInfo(fromZone);
    final sourceTz = tz.TZDateTime(
      fromInfo.location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return sourceTz.toUtc();
  }

  /// Mengonversi DateTime (UTC atau lokal) menjadi TZDateTime di zona tertentu
  static tz.TZDateTime inZone(DateTime dateTime, String zoneCode) {
    ensureInitialized();
    final info = getInfo(zoneCode);
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return tz.TZDateTime.from(utc, info.location);
  }

  /// Format tanggal dalam Bahasa Indonesia
  static String formatIndonesianDate(DateTime date) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  /// Format ringkas tanggal (contoh: "22 Okt 2026")
  static String formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Fungsi helper untuk menampilkan waktu di 4 zona waktu dalam satu baris (backward-compatible)
String zoneText(DateTime utc) {
  TimeZoneService.ensureInitialized();
  return zones.entries
      .map((e) {
        final t = tz.TZDateTime.from(utc, tz.getLocation(e.value));
        return '${e.key} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      })
      .join(' | ');
}
