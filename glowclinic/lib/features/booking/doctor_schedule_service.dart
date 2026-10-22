import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/booking/zones.dart';

/// Model data jadwal praktik harian dokter.
class DoctorDailySchedule {
  final int doctorId;
  final int branchId;
  final int dayOfWeek; // 1 = Senin, ..., 7 = Minggu
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String? note;

  const DoctorDailySchedule({
    required this.doctorId,
    required this.branchId,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.note,
  });

  int get startMinutesTotal => startHour * 60 + startMinute;
  int get endMinutesTotal => endHour * 60 + endMinute;

  String get formattedHours =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} - '
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}

/// Model data slot waktu booking.
class BookingSlot {
  final DateTime time; // Waktu dalam zona aktif
  final DateTime timeUtc; // Waktu UTC untuk penyimpanan
  final String timeLabel; // Format "HH:mm"
  final bool isAvailable;
  final String statusLabel; // "Tersedia", "Sudah dipesan", "Waktu telah lewat", dll.

  const BookingSlot({
    required this.time,
    required this.timeUtc,
    required this.timeLabel,
    required this.isAvailable,
    required this.statusLabel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingSlot &&
          runtimeType == other.runtimeType &&
          timeUtc.millisecondsSinceEpoch == other.timeUtc.millisecondsSinceEpoch;

  @override
  int get hashCode => timeUtc.millisecondsSinceEpoch.hashCode;
}

/// Service untuk menangani logika jadwal praktik dokter dan slot booking.
class DoctorScheduleService {
  static const Map<String, int> _dayMap = {
    'senin': DateTime.monday,
    'selasa': DateTime.tuesday,
    'rabu': DateTime.wednesday,
    'kamis': DateTime.thursday,
    'jumat': DateTime.friday,
    'sabtu': DateTime.saturday,
    'minggu': DateTime.sunday,
  };

  /// Mengambil daftar dokter yang bertugas di cabang tertentu.
  /// Jika [date] diberikan, hanya mengembalikan dokter yang memiliki jadwal praktik
  /// pada hari tersebut (day of week) di cabang tersebut.
  static Future<List<Map<String, dynamic>>> getDoctorsForBranch({
    required int branchId,
    DateTime? date,
  }) async {
    List<Map<String, dynamic>> results;

    if (date == null) {
      // Ambil dokter yang bertugas di cabang ini via doctor_schedules atau fallback doctors.branch_id
      results = await qry(
        '''
        SELECT DISTINCT d.* 
        FROM doctors d
        WHERE EXISTS (
          SELECT 1 FROM doctor_schedules ds WHERE ds.doctor_id = d.id AND ds.branch_id = ?
        )
        OR (
          NOT EXISTS (SELECT 1 FROM doctor_schedules ds2 WHERE ds2.doctor_id = d.id)
          AND d.branch_id = ?
        )
        ORDER BY d.nama
        ''',
        [branchId, branchId],
      );
    } else {
      final targetDay = date.weekday; // 1 = Senin, ..., 7 = Minggu
      final scheduledDocs = await qry(
        '''
        SELECT DISTINCT d.* 
        FROM doctors d
        JOIN doctor_schedules ds ON ds.doctor_id = d.id
        WHERE ds.branch_id = ? AND ds.hari = ?
        ORDER BY d.nama
        ''',
        [branchId, targetDay],
      );

      final fallbackDocs = await qry(
        '''
        SELECT * FROM doctors d
        WHERE d.branch_id = ?
          AND NOT EXISTS (SELECT 1 FROM doctor_schedules ds WHERE ds.doctor_id = d.id)
        ORDER BY d.nama
        ''',
        [branchId],
      );

      final combined = <int, Map<String, dynamic>>{};
      for (final doc in scheduledDocs) {
        final id = (doc['id'] as num?)?.toInt() ?? 0;
        if (id > 0) combined[id] = doc;
      }
      for (final doc in fallbackDocs) {
        final id = (doc['id'] as num?)?.toInt() ?? 0;
        final jadwal = doc['jadwal_praktik']?.toString() ?? '';
        if (id > 0 && _isDoctorPracticingOnDay(jadwal, targetDay)) {
          combined[id] = doc;
        }
      }
      results = combined.values.toList();
    }

    return results;
  }

  /// Memeriksa apakah teks jadwal dokter mencakup hari tertentu.
  static bool _isDoctorPracticingOnDay(String jadwalText, int dayOfWeek) {
    if (jadwalText.trim().isEmpty) return true; // Asumsi fleksibel jika kosong

    final parts = jadwalText.toLowerCase().split(',');
    if (parts.isEmpty) return true;

    final daysPart = parts[0].trim(); // e.g. "senin - rabu" atau "jumat - sabtu"
    if (daysPart.contains('-')) {
      final range = daysPart.split('-');
      if (range.length == 2) {
        final startDay = _dayMap[range[0].trim()];
        final endDay = _dayMap[range[1].trim()];
        if (startDay != null && endDay != null) {
          if (startDay <= endDay) {
            return dayOfWeek >= startDay && dayOfWeek <= endDay;
          } else {
            return dayOfWeek >= startDay || dayOfWeek <= endDay;
          }
        }
      }
    } else {
      final singleDay = _dayMap[daysPart.trim()];
      if (singleDay != null) {
        return dayOfWeek == singleDay;
      }
    }

    return false;
  }

  /// Mengambil jadwal praktik dokter pada tanggal dan cabang tertentu.
  static Future<DoctorDailySchedule?> getSchedule({
    required int doctorId,
    required int branchId,
    required DateTime date,
  }) async {
    final targetDay = date.weekday;

    // Cek di tabel doctor_schedules terlebih dahulu
    final rows = await qry(
      '''
      SELECT * FROM doctor_schedules 
      WHERE doctor_id = ? AND branch_id = ? AND hari = ?
      LIMIT 1
      ''',
      [doctorId, branchId, targetDay],
    );

    if (rows.isNotEmpty) {
      final r = rows.first;
      final jamMulai = r['jam_mulai']?.toString() ?? '09:00';
      final jamSelesai = r['jam_selesai']?.toString() ?? '17:00';

      final startParts = jamMulai.split(':');
      final endParts = jamSelesai.split(':');

      return DoctorDailySchedule(
        doctorId: doctorId,
        branchId: branchId,
        dayOfWeek: targetDay,
        startHour: int.tryParse(startParts[0]) ?? 9,
        startMinute: int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0,
        endHour: int.tryParse(endParts[0]) ?? 17,
        endMinute: int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0,
        note: r['catatan']?.toString(),
      );
    }

    // Fallback: baca dari kolom doctors.jadwal_praktik
    final docRows = await qry(
      'SELECT * FROM doctors WHERE id = ?',
      [doctorId],
    );

    if (docRows.isEmpty) return null;
    final doc = docRows.first;
    final jadwalText = doc['jadwal_praktik']?.toString() ?? '';

    if (!_isDoctorPracticingOnDay(jadwalText, targetDay)) {
      return null;
    }

    // Parse jam dari teks, contoh: "Senin - Rabu, 09:00-14:00"
    int sHour = 9, sMin = 0, eHour = 17, eMin = 0;
    if (jadwalText.contains(',')) {
      final timePart = jadwalText.split(',')[1].trim();
      if (timePart.contains('-')) {
        final t = timePart.split('-');
        final pStart = t[0].trim().split(':');
        final pEnd = t[1].trim().split(':');
        sHour = int.tryParse(pStart[0]) ?? 9;
        sMin = int.tryParse(pStart.length > 1 ? pStart[1] : '0') ?? 0;
        eHour = int.tryParse(pEnd[0]) ?? 17;
        eMin = int.tryParse(pEnd.length > 1 ? pEnd[1] : '0') ?? 0;
      }
    }

    return DoctorDailySchedule(
      doctorId: doctorId,
      branchId: branchId,
      dayOfWeek: targetDay,
      startHour: sHour,
      startMinute: sMin,
      endHour: eHour,
      endMinute: eMin,
      note: jadwalText,
    );
  }

  /// Menghitung seluruh slot waktu kosong berdasarkan:
  /// - Jam praktik dokter pada tanggal & cabang tersebut (waktu operasional klinik WIB)
  /// - Durasi treatment yang dipilih
  /// - Interval slot (default 30 menit)
  /// - Booking yang sudah ada (status bukan 'cancelled' atau 'batal')
  /// - Zona waktu yang dipilih untuk display (default 'WIB')
  static Future<List<BookingSlot>> calculateAvailableSlots({
    required int doctorId,
    required int branchId,
    required DateTime date,
    required int treatmentDurationMinutes,
    String selectedZone = 'WIB',
    int slotIntervalMinutes = 30,
  }) async {
    final schedule = await getSchedule(
      doctorId: doctorId,
      branchId: branchId,
      date: date,
    );

    if (schedule == null) {
      return [];
    }

    // Ambil semua booking aktif untuk dokter ini (bukan dibatalkan)
    final existingBookings = await qry(
      '''
      SELECT b.id, b.waktu_utc, b.status, 
             COALESCE(b.durasi_menit, t.durasi_menit, 60) AS durasi
      FROM bookings b
      LEFT JOIN treatments t ON t.id = b.treatment_id
      WHERE b.doctor_id = ? 
        AND LOWER(TRIM(b.status)) NOT IN ('cancelled', 'batal')
      ''',
      [doctorId],
    );

    final parsedBookings = <Map<String, dynamic>>[];
    for (final b in existingBookings) {
      final waktuUtcStr = b['waktu_utc']?.toString();
      if (waktuUtcStr == null) continue;
      final startUtc = DateTime.tryParse(waktuUtcStr)?.toUtc();
      if (startUtc == null) continue;

      final bDuration = (b['durasi'] as num?)?.toInt() ?? 60;
      final endUtc = startUtc.add(Duration(minutes: bDuration));

      parsedBookings.add({
        'startUtc': startUtc,
        'endUtc': endUtc,
      });
    }

    final slots = <BookingSlot>[];
    final nowUtc = DateTime.now().toUtc();

    int currentMinutes = schedule.startMinutesTotal;
    final endLimit = schedule.endMinutesTotal;

    // Slot hanya ditawarkan jika treatment selesai sebelum jam praktik berakhir
    while (currentMinutes + treatmentDurationMinutes <= endLimit) {
      final slotHour = currentMinutes ~/ 60;
      final slotMinute = currentMinutes % 60;

      // Waktu slot dihitung dalam waktu lokal klinik (WIB)
      final slotUtc = TimeZoneService.toUtc(
        date: date,
        hour: slotHour,
        minute: slotMinute,
        fromZone: 'WIB',
      );

      final slotEndUtc = slotUtc.add(Duration(minutes: treatmentDurationMinutes));

      // Konversi ke zona waktu pilihan pengguna untuk display
      final displayTime = TimeZoneService.inZone(slotUtc, selectedZone);
      final displayHour = displayTime.hour.toString().padLeft(2, '0');
      final displayMinute = displayTime.minute.toString().padLeft(2, '0');
      final label = '$displayHour:$displayMinute';

      bool isConflict = false;
      String statusLabel = 'Tersedia';

      // 1. Cek apakah slot sudah lewat
      if (slotUtc.isBefore(nowUtc)) {
        isConflict = true;
        statusLabel = 'Waktu telah lewat';
      }

      // 2. Cek konflik tumpang tindih dengan booking lain milik dokter yang sama
      // Formula interval overlap: slotStart < bEnd && bStart < slotEnd
      if (!isConflict) {
        for (final b in parsedBookings) {
          final bStart = b['startUtc'] as DateTime;
          final bEnd = b['endUtc'] as DateTime;

          if (slotUtc.isBefore(bEnd) && bStart.isBefore(slotEndUtc)) {
            isConflict = true;
            statusLabel = 'Sudah dipesan';
            break;
          }
        }
      }

      slots.add(BookingSlot(
        time: DateTime(
          displayTime.year,
          displayTime.month,
          displayTime.day,
          displayTime.hour,
          displayTime.minute,
        ),
        timeUtc: slotUtc,
        timeLabel: label,
        isAvailable: !isConflict,
        statusLabel: statusLabel,
      ));

      currentMinutes += slotIntervalMinutes;
    }

    return slots;
  }

  /// Validasi ketersediaan slot sebelum konfirmasi booking disimpan ke database.
  /// Memeriksa kembali secara langsung ke database apakah slot masih bebas dari konflik.
  static Future<bool> isSlotAvailable({
    required int doctorId,
    required DateTime startUtc,
    required int durationMinutes,
    int? branchId,
    int? excludeBookingId,
  }) async {
    final endUtc = startUtc.add(Duration(minutes: durationMinutes));

    // Jika branchId disertakan, validasi apakah dokter bertugas dan waktu berada dalam jam praktik
    if (branchId != null) {
      final clinicZt = TimeZoneService.inZone(startUtc, 'WIB');
      final clinicDate = DateTime(clinicZt.year, clinicZt.month, clinicZt.day);
      final schedule = await getSchedule(
        doctorId: doctorId,
        branchId: branchId,
        date: clinicDate,
      );

      if (schedule == null) return false;

      final startMinutes = clinicZt.hour * 60 + clinicZt.minute;
      final endMinutes = startMinutes + durationMinutes;

      if (startMinutes < schedule.startMinutesTotal || endMinutes > schedule.endMinutesTotal) {
        return false;
      }
    }

    // Ambil semua booking dokter yang bertabrakan waktu
    final rows = await qry(
      '''
      SELECT b.id, b.waktu_utc, 
             COALESCE(b.durasi_menit, t.durasi_menit, 60) AS durasi
      FROM bookings b
      LEFT JOIN treatments t ON t.id = b.treatment_id
      WHERE b.doctor_id = ?
        AND LOWER(TRIM(b.status)) NOT IN ('cancelled', 'batal')
      ''',
      [doctorId],
    );

    for (final r in rows) {
      if (excludeBookingId != null && r['id'] == excludeBookingId) continue;

      final bUtcStr = r['waktu_utc']?.toString();
      if (bUtcStr == null) continue;
      final bStart = DateTime.tryParse(bUtcStr)?.toUtc();
      if (bStart == null) continue;

      final bDuration = (r['durasi'] as num?)?.toInt() ?? 60;
      final bEnd = bStart.add(Duration(minutes: bDuration));

      if (startUtc.isBefore(bEnd) && bStart.isBefore(endUtc)) {
        return false; // Bertabrakan!
      }
    }

    return true;
  }
}
