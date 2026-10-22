import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/features/booking/zones.dart';

void main() {
  setUpAll(() {
    TimeZoneService.ensureInitialized();
  });

  group('TimeZoneService — Konversi Waktu', () {
    // ── Skenario 1: WIB → WITA ─────────────────────────────
    test('WIB 10:00 → WITA 11:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'WITA',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(11));
      expect(r.targetTz.minute, equals(0));
      expect(r.isDateChanged, isFalse);
      expect(r.dayDifference, equals(0));
    });

    // ── Skenario 2: WIB → WIT ──────────────────────────────
    test('WIB 10:00 → WIT 12:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'WIT',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(12));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 3: WITA → WIB ─────────────────────────────
    test('WITA 10:00 → WIB 09:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'WITA',
        toZone: 'WIB',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(9));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 4: WIT → WITA ─────────────────────────────
    test('WIT 10:00 → WITA 09:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'WIT',
        toZone: 'WITA',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(9));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 5: WIB → London (Summer/BST: UTC+1) ───────
    test('WIB 10:00 → London 04:00 saat summer (BST)', () {
      // 15 Juni: London BST (UTC+1), WIB UTC+7, selisih 6 jam
      final r = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'London',
        date: DateTime(2026, 6, 15),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(4));
      expect(r.targetTz.minute, equals(0));
      expect(r.isLondonDst, isTrue);
      expect(r.londonDstStatus, contains('BST'));
    });

    // ── Skenario 6: WIB → London (Winter/GMT: UTC+0) ───────
    test('WIB 10:00 → London 03:00 saat winter (GMT)', () {
      // 15 Januari: London GMT (UTC+0), WIB UTC+7, selisih 7 jam
      final r = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'London',
        date: DateTime(2026, 1, 15),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(3));
      expect(r.targetTz.minute, equals(0));
      expect(r.isLondonDst, isFalse);
      expect(r.londonDstStatus, contains('GMT'));
    });

    // ── Skenario 7a: London → WIB ──────────────────────────
    test('London (BST) 10:00 → WIB 16:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'London',
        toZone: 'WIB',
        date: DateTime(2026, 6, 15),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(16));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 7b: London → WITA ─────────────────────────
    test('London (BST) 10:00 → WITA 17:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'London',
        toZone: 'WITA',
        date: DateTime(2026, 6, 15),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(17));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 7c: London → WIT ──────────────────────────
    test('London (BST) 10:00 → WIT 18:00', () {
      final r = TimeZoneService.convert(
        fromZone: 'London',
        toZone: 'WIT',
        date: DateTime(2026, 6, 15),
        hour: 10,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(18));
      expect(r.targetTz.minute, equals(0));
    });

    // ── Skenario 8: Pergantian tanggal — London malam ke WIB ────
    test('London 20:00 summer → WIB 02:00 keesokan hari', () {
      final r = TimeZoneService.convert(
        fromZone: 'London',
        toZone: 'WIB',
        date: DateTime(2026, 6, 15),
        hour: 20,
        minute: 0,
      );
      expect(r.targetTz.hour, equals(2));
      expect(r.targetTz.minute, equals(0));
      expect(r.isDateChanged, isTrue);
      expect(r.dayDifference, equals(1));
      expect(r.dateChangeNotice, contains('+1 Hari'));
    });

    // ── Skenario 9: Tukar zona — hasil berlawanan arah ─────
    test('Tukar zona: WIB→WITA lalu balik WITA→WIB memberikan waktu yang sama', () {
      final r1 = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'WITA',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 30,
      );
      final r2 = TimeZoneService.convert(
        fromZone: 'WITA',
        toZone: 'WIB',
        date: DateTime(2026, 6, 1),
        hour: r1.targetTz.hour,
        minute: r1.targetTz.minute,
      );
      expect(r2.targetTz.hour, equals(10));
      expect(r2.targetTz.minute, equals(30));
    });

    // ── Skenario 10: WIT 02:00 → WIB → harus sebelumnya ───
    test('WIT 02:00 → WIB memberikan pergantian tanggal negatif (kemarin)', () {
      final r = TimeZoneService.convert(
        fromZone: 'WIT',
        toZone: 'WIB',
        date: DateTime(2026, 6, 2),
        hour: 0,
        minute: 0,
      );
      // WIT UTC+9, WIB UTC+7, selisih -2 jam → 00:00 WIT = 22:00 WIB hari sebelumnya
      expect(r.targetTz.hour, equals(22));
      expect(r.dayDifference, equals(-1));
      expect(r.dateChangeNotice, contains('-1 Hari'));
    });

    // ── Skenario 11: convertToAllZones ─────────────────────
    test('convertToAllZones dari WIB 10:00 menghasilkan 4 zona', () {
      final results = TimeZoneService.convertToAllZones(
        fromZone: 'WIB',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(results.length, equals(4));
      expect(results['WIB']!.targetTz.hour, equals(10));  // sama
      expect(results['WITA']!.targetTz.hour, equals(11));
      expect(results['WIT']!.targetTz.hour, equals(12));
      // London summer = 04:00
      expect(results['London']!.targetTz.hour, equals(4));
    });

    // ── Skenario 12: Format output ──────────────────────────
    test('formattedTime format HH:mm benar', () {
      final r = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'WITA',
        date: DateTime(2026, 6, 1),
        hour: 9,
        minute: 5,
      );
      expect(r.formattedTime, equals('10:05'));
      expect(r.formattedTimeWithZone, equals('10:05 WITA'));
    });

    // ── Skenario 13: TimeZoneService.toUtc & inZone invariance ──
    test('Memilih waktu di London terkonversi ke UTC dan terbaca akurat di semua zona', () {
      // User memilih 10:00 di London pada 1 Juni 2026 (BST = UTC+1)
      final utc = TimeZoneService.toUtc(
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 30,
        fromZone: 'London',
      );

      // UTC harus 09:30
      expect(utc.hour, equals(9));
      expect(utc.minute, equals(30));

      // Saat dibaca di zona lain menggunakan inZone:
      final inLondon = TimeZoneService.inZone(utc, 'London');
      final inWib = TimeZoneService.inZone(utc, 'WIB');
      final inWita = TimeZoneService.inZone(utc, 'WITA');
      final inWit = TimeZoneService.inZone(utc, 'WIT');

      expect(inLondon.hour, equals(10));
      expect(inLondon.minute, equals(30));
      expect(inWib.hour, equals(16)); // UTC+7 -> 09:30 + 7 = 16:30
      expect(inWita.hour, equals(17)); // UTC+8 -> 17:30
      expect(inWit.hour, equals(18)); // UTC+9 -> 18:30
    });

    // ── Skenario 14: Pergantian tanggal lintas tengah malam ──
    test('Pergantian zona waktu menyesuaikan tanggal dengan benar', () {
      // User memilih 02:00 WIB pada 10 Oktober 2026
      // UTC: 9 Oktober 2026 19:00
      final utc = TimeZoneService.toUtc(
        date: DateTime(2026, 10, 10),
        hour: 2,
        minute: 0,
        fromZone: 'WIB',
      );

      final inWib = TimeZoneService.inZone(utc, 'WIB');
      final inLondon = TimeZoneService.inZone(utc, 'London');

      // Di WIB: tanggal 10 Oktober 2026 jam 02:00
      expect(inWib.day, equals(10));
      expect(inWib.hour, equals(2));

      // Di London (BST UTC+1 saat Oktober): jam 20:00 tanggal 9 Oktober 2026 (hari sebelumnya)
      expect(inLondon.day, equals(9));
      expect(inLondon.hour, equals(20));
    });

    // ── Skenario 15: Pergantian zona tidak mengubah momen waktu (UTC instant) ──
    test('Pergantian zona waktu tidak mengubah nilai UTC acuan', () {
      final utcReference = TimeZoneService.toUtc(
        date: DateTime(2026, 12, 1),
        hour: 15,
        minute: 45,
        fromZone: 'WITA',
      );

      // Moment waktu tetap sama
      expect(TimeZoneService.inZone(utcReference, 'WITA').toUtc(), equals(utcReference));
      expect(TimeZoneService.inZone(utcReference, 'WIB').toUtc(), equals(utcReference));
      expect(TimeZoneService.inZone(utcReference, 'London').toUtc(), equals(utcReference));
      expect(TimeZoneService.inZone(utcReference, 'WIT').toUtc(), equals(utcReference));
    });
  });
}

