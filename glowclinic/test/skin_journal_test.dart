import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/skin/skin_journal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Inisialisasi tabel users, bookings, dan skin_journals
    await db.execute(
      "create table users(id integer primary key autoincrement, nama text, email text unique, no_hp text, role text not null default 'pasien')",
    );
    await db.execute(
      "create table treatments(id integer primary key autoincrement, nama text, kategori text, deskripsi text, durasi_menit integer, harga_idr integer)",
    );
    await db.execute(
      "create table doctors(id integer primary key autoincrement, nama text, spesialisasi text, branch_id integer, photo_path text)",
    );
    await db.execute(
      "create table bookings(id integer primary key autoincrement, user_id integer, doctor_id integer, branch_id integer, treatment_id integer, treatment_nama text, waktu_utc text, status text default 'done', catatan_dokter text)",
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skin_journals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        booking_id INTEGER,
        tanggal TEXT NOT NULL,
        kondisi_kulit TEXT NOT NULL,
        keluhan TEXT,
        catatan TEXT,
        produk TEXT,
        photo_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Buat data user pengujian
    await db.insert('users', {'id': 1, 'nama': 'Siti Rahma', 'email': 'siti@test.com', 'role': 'pasien'});
    await db.insert('users', {'id': 2, 'nama': 'Budi Santoso', 'email': 'budi@test.com', 'role': 'pasien'});

    // Buat data booking berstatus selesai
    await db.insert('bookings', {
      'id': 101,
      'user_id': 1,
      'doctor_id': 1,
      'treatment_nama': 'Acne Clear Facial',
      'waktu_utc': '2026-10-20T10:00:00Z',
      'status': 'done',
      'catatan_dokter': 'Kulit membaik, gunakan tabir surya setiap hari.',
    });

    myId = 1;
  });

  tearDown(() async {
    await db.close();
  });

  group('Database & Logic Tests - Skin Journal', () {
    test('1. Menambahkan entri Jurnal Kulit baru dan tersimpan di database', () async {
      final id = await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Sensitif',
        'keluhan': 'Kemerahan sedikit di area pipi',
        'catatan': 'Hari pertama setelah facial acne',
        'produk': 'Serum Calming Centella',
        'photo_path': null,
      });

      expect(id, greaterThan(0));

      final rows = await db.query('skin_journals', where: 'id = ?', whereArgs: [id]);
      expect(rows.length, 1);
      expect(rows.first['user_id'], 1);
      expect(rows.first['booking_id'], 101);
      expect(rows.first['kondisi_kulit'], 'Sensitif');
      expect(rows.first['keluhan'], 'Kemerahan sedikit di area pipi');
      expect(rows.first['catatan'], 'Hari pertama setelah facial acne');
      expect(rows.first['produk'], 'Serum Calming Centella');
    });

    test('2. Pengguna hanya dapat mengakses jurnal miliknya sendiri', () async {
      // User 1 buat 2 jurnal
      await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Berminyak',
      });
      await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': null,
        'tanggal': '2026-10-22',
        'kondisi_kulit': 'Normal',
      });

      // User 2 buat 1 jurnal
      await db.insert('skin_journals', {
        'user_id': 2,
        'booking_id': null,
        'tanggal': '2026-10-22',
        'kondisi_kulit': 'Kering',
      });

      // Query untuk user 1
      final user1Journals = await db.query(
        'skin_journals',
        where: 'user_id = ?',
        whereArgs: [1],
      );
      expect(user1Journals.length, 2);
      expect(user1Journals.every((j) => j['user_id'] == 1), isTrue);

      // Query untuk user 2
      final user2Journals = await db.query(
        'skin_journals',
        where: 'user_id = ?',
        whereArgs: [2],
      );
      expect(user2Journals.length, 1);
      expect(user2Journals.first['user_id'], 2);
      expect(user2Journals.first['kondisi_kulit'], 'Kering');
    });

    test('3. Memperbarui (edit) entri Jurnal Kulit', () async {
      final id = await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Berminyak',
        'catatan': 'Catatan awal',
      });

      final count = await db.update(
        'skin_journals',
        {
          'kondisi_kulit': 'Normal',
          'catatan': 'Kondisi membaik signifikan',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, 1],
      );

      expect(count, 1);

      final updated = await db.query('skin_journals', where: 'id = ?', whereArgs: [id]);
      expect(updated.first['kondisi_kulit'], 'Normal');
      expect(updated.first['catatan'], 'Kondisi membaik signifikan');
    });

    test('4. Menghapus entri Jurnal Kulit', () async {
      final id = await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Sensitif',
      });

      final deletedCount = await db.delete(
        'skin_journals',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, 1],
      );

      expect(deletedCount, 1);

      final remaining = await db.query('skin_journals', where: 'id = ?', whereArgs: [id]);
      expect(remaining.isEmpty, isTrue);
    });

    test('5. Hubungan jurnal dengan booking treatment yang selesai', () async {
      await db.insert('skin_journals', {
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Kombinasi',
        'catatan': 'Treatment berjalan lancar',
      });

      // Join query antara jurnal dan booking
      final result = await db.rawQuery('''
        SELECT j.*, b.treatment_nama, b.status as booking_status, b.catatan_dokter
        FROM skin_journals j
        LEFT JOIN bookings b ON j.booking_id = b.id
        WHERE j.user_id = ?
      ''', [1]);

      expect(result.length, 1);
      expect(result.first['treatment_nama'], 'Acne Clear Facial');
      expect(result.first['booking_status'], 'done');
      expect(result.first['catatan_dokter'], contains('Kulit membaik'));
    });
  });

  group('Widget Tests - Skin Journal Screens', () {
    testWidgets('6. Menampilkan SkinJournalScreen dengan daftar kosong dan tombol Tulis Jurnal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkinJournalScreen(
            booking: {
              'id': 101,
              'treatment_nama': 'Acne Clear Facial',
              'waktu_utc': '2026-10-20T10:00:00Z',
              'doctor_nama': 'dr. Amanda',
            },
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();

      expect(find.text('Jurnal Kulit'), findsOneWidget);
      expect(find.text('Acne Clear Facial'), findsOneWidget);
      expect(find.text('Belum ada catatan jurnal'), findsOneWidget);
      expect(find.text('Tulis Jurnal'), findsOneWidget);
    });

    testWidgets('7. Formulir Jurnal Kulit menampilkan chip kondisi kulit dan tombol Simpan Jurnal', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SkinJournalFormScreen(
            initialBookingId: 101,
            treatmentNama: 'Acne Clear Facial',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tulis Jurnal Kulit'), findsOneWidget);
      expect(find.text('Kondisi Kulit Saat Ini *'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Kering'), findsOneWidget);
      expect(find.text('Berminyak'), findsOneWidget);
      expect(find.text('Kombinasi'), findsOneWidget);
      expect(find.text('Sensitif'), findsOneWidget);
      expect(find.text('Simpan Jurnal'), findsOneWidget);
    });

    testWidgets('8. Menampilkan detail jurnal pada SkinJournalDetailScreen', (tester) async {
      final sampleJournal = {
        'id': 1,
        'user_id': 1,
        'booking_id': 101,
        'tanggal': '2026-10-21',
        'kondisi_kulit': 'Berminyak',
        'keluhan': 'Minyak berlebih di T-zone',
        'catatan': 'Gunakan toner astringent 2 kali sehari',
        'produk': 'Toner Salicylic Acid',
        'photo_path': null,
        'created_at': '2026-10-21T08:00:00Z',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: SkinJournalDetailScreen(
            journal: sampleJournal,
            treatmentNama: 'Acne Clear Facial',
            doctorNama: 'dr. Amanda',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Detail Jurnal Kulit'), findsOneWidget);
      expect(find.text('Berminyak'), findsWidgets);
      expect(find.text('Minyak berlebih di T-zone'), findsOneWidget);
      expect(find.text('Gunakan toner astringent 2 kali sehari'), findsOneWidget);
      expect(find.text('Toner Salicylic Acid'), findsOneWidget);
    });

    testWidgets('9. Formulir Jurnal Kulit tidak mengalami overflow pada layar kecil (lebar 320 px)', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SkinJournalFormScreen(
            initialBookingId: 101,
            treatmentNama: 'Acne Clear Facial Peremajaan Laser Kulit Super Panjang',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan semua teks label panjang di dalam header kartu ditemukan dan tidak melempar error overflow
      expect(find.text('Kondisi Kulit Saat Ini *'), findsOneWidget);
      expect(find.text('Keluhan yang Dialami (Opsional)'), findsOneWidget);
      expect(find.text('Catatan Perkembangan (Opsional)'), findsOneWidget);
      expect(find.text('Produk Perawatan yang Digunakan (Opsional)'), findsOneWidget);
      expect(find.text('Foto Kondisi Kulit (Opsional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
