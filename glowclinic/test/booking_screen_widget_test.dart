import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/booking/booking_screen.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    TimeZoneService.ensureInitialized();
  });

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await db.execute(
      "create table users(id integer primary key autoincrement, nama text, email text unique, no_hp text, role text not null default 'pasien', alergi text, tipe_kulit text, photo_path text, poin integer default 0, salt text, pass_hash text)",
    );
    await db.execute(
      "create table branches(id integer primary key autoincrement, nama text, alamat text, lat real, lng real, jam_buka text)",
    );
    await db.execute(
      "create table doctors(id integer primary key autoincrement, nama text, spesialisasi text, branch_id integer, pendidikan text, pengalaman_tahun integer default 0, deskripsi text, jadwal_praktik text, photo_path text)",
    );
    await db.execute(
      "create table treatments(id integer primary key autoincrement, nama text, kategori text, deskripsi text, durasi_menit integer, harga_idr integer)",
    );
    await db.execute(
      "create table bookings(id integer primary key autoincrement, user_id integer, doctor_id integer, branch_id integer, treatment_id integer, treatment_nama text, waktu_utc text, durasi_menit integer default 60, status text default 'pending', status_bayar text default 'belum_bayar', metode_bayar text, kode_bayar text, total_idr integer, mata_uang text default 'IDR', kurs real default 1.0, total_bayar real, catatan_dokter text, spin_hadiah text, created_at text default current_timestamp)",
    );
    await db.execute(
      "create table doctor_schedules(id integer primary key autoincrement, doctor_id integer, branch_id integer, hari integer, jam_mulai text, jam_selesai text, catatan text)",
    );
    await db.execute(
      "create table notifications(id integer primary key autoincrement, user_id integer, judul text, isi text, tipe text default 'info', booking_id integer, dibaca integer default 0, shown integer default 0, waktu_utc text)",
    );
    await db.execute(
      "create table blocks(id integer primary key autoincrement, idx integer, ts text, data text, prev_hash text, hash text)",
    );

    // Data awal
    await db.insert('branches', {'id': 1, 'nama': 'GlowClinic Pusat', 'alamat': 'Yogyakarta Pusat', 'jam_buka': '09:00-18:00'});
    await db.insert('branches', {'id': 2, 'nama': 'GlowClinic Sleman', 'alamat': 'Sleman', 'jam_buka': '09:00-18:00'});

    await db.insert('treatments', {
      'id': 1,
      'nama': 'Facial Medis',
      'kategori': 'Facial',
      'deskripsi': 'Pembersihan kulit',
      'durasi_menit': 60,
      'harga_idr': 350000,
    });

    await db.insert('doctors', {
      'id': 1,
      'nama': 'dr. Rina Aulia, Sp.KK',
      'spesialisasi': 'Dermatologi',
      'branch_id': 1,
      'jadwal_praktik': 'Senin - Minggu, 09:00-17:00',
    });
    for (int day = 1; day <= 7; day++) {
      await db.insert('doctor_schedules', {
        'doctor_id': 1,
        'branch_id': 1,
        'hari': day,
        'jam_mulai': '09:00',
        'jam_selesai': '17:00',
        'catatan': 'Setiap hari, 09:00-17:00',
      });
    }

    myId = 1;
    await db.insert('users', {
      'id': 1,
      'nama': 'Pasien Demo',
      'email': 'pasien@glowclinic.com',
    });
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('BookingScreen render lancar tanpa error saat memilih tanggal dan slot waktu', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final treatmentData = {
      'id': 1,
      'nama': 'Facial Medis',
      'kategori': 'Facial',
      'durasi_menit': 60,
      'harga_idr': 350000,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: BookingScreen(treatmentData),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    // Verifikasi bagian header dan langkah booking
    expect(find.text('Booking Perawatan'), findsOneWidget);
    expect(find.text('Pilih Cabang'), findsWidgets);
    expect(find.text('GlowClinic Pusat'), findsWidgets);
    expect(find.text('Pilih Tanggal'), findsOneWidget);

    // Dokter otomatis terpilih atau tersedia
    expect(find.textContaining('dr. Rina Aulia'), findsWidgets);

    // Ganti tanggal (klik tombol hari ke-2)
    final dayButtons = find.byType(InkWell);
    expect(dayButtons, findsWidgets);

    // Tap salah satu tanggal
    await tester.tap(dayButtons.at(2));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();

    // Pastikan tidak ada assertion error atau crash
    expect(tester.takeException(), isNull);

    // Slot waktu harus ter-render
    expect(find.text('Pilih Slot Waktu'), findsOneWidget);
    expect(find.text('Tersedia'), findsWidgets);

    // Tap slot waktu '09:00' yang tersedia (memilih jadwal)
    final slot0900 = find.text('09:00');
    expect(slot0900, findsWidgets);
    await tester.tap(slot0900.first);
    await tester.pump();

    // Verifikasi tidak ada error saat memilih jadwal
    expect(tester.takeException(), isNull);

    // Verifikasi tombol Konfirmasi Booking aktif
    final confirmButton = find.widgetWithText(FilledButton, 'Konfirmasi Booking');
    expect(confirmButton, findsOneWidget);

    // Verifikasi Ringkasan Booking terupdate dengan jam selesai
    expect(find.text('Perkiraan Selesai'), findsOneWidget);
    expect(find.text('Belum dipilih'), findsNothing);
  });
}
