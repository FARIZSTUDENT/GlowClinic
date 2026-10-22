import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/booking/doctor_schedule_service.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    TimeZoneService.ensureInitialized();
  });

  setUp(() async {
    // Gunakan in-memory SQLite database terisolasi untuk tiap pengujian
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    // Buat tabel dari skema resmi
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

    // Seed cabang
    await db.insert('branches', {'id': 1, 'nama': 'GlowClinic Pusat', 'alamat': 'Yogyakarta Pusat', 'jam_buka': '09:00-18:00'});
    await db.insert('branches', {'id': 2, 'nama': 'GlowClinic Sleman', 'alamat': 'Sleman', 'jam_buka': '09:00-18:00'});
    await db.insert('branches', {'id': 3, 'nama': 'GlowClinic Bantul', 'alamat': 'Bantul', 'jam_buka': '09:00-18:00'});

    // Seed treatments
    await db.insert('treatments', {
      'id': 1,
      'nama': 'Facial Medis',
      'kategori': 'Facial',
      'deskripsi': 'Pembersihan kulit',
      'durasi_menit': 60,
      'harga_idr': 350000,
    });
    await db.insert('treatments', {
      'id': 2,
      'nama': 'Laser Rejuvenation',
      'kategori': 'Laser',
      'deskripsi': 'Peremajaan laser',
      'durasi_menit': 45,
      'harga_idr': 1200000,
    });
    await db.insert('treatments', {
      'id': 3,
      'nama': 'Konsultasi Singkat',
      'kategori': 'Konsultasi',
      'deskripsi': 'Konsultasi dokter',
      'durasi_menit': 30,
      'harga_idr': 150000,
    });

    // Seed Dokter:
    // Dokter 1 (Dr. Rina) bertugas di Cabang 1 (Senin-Rabu 09:00-14:00) dan Cabang 2 (Kamis-Jumat 10:00-15:00)
    await db.insert('doctors', {
      'id': 1,
      'nama': 'dr. Rina Aulia, Sp.KK',
      'spesialisasi': 'Dermatologi',
      'branch_id': 1,
      'jadwal_praktik': 'Senin - Rabu, 09:00-14:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 1,
      'branch_id': 1,
      'hari': 1, // Senin
      'jam_mulai': '09:00',
      'jam_selesai': '14:00',
      'catatan': 'Senin, 09:00-14:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 1,
      'branch_id': 1,
      'hari': 2, // Selasa
      'jam_mulai': '09:00',
      'jam_selesai': '14:00',
      'catatan': 'Selasa, 09:00-14:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 1,
      'branch_id': 2,
      'hari': 4, // Kamis
      'jam_mulai': '10:00',
      'jam_selesai': '15:00',
      'catatan': 'Kamis, 10:00-15:00',
    });

    // Dokter 2 (Dr. Kevin) bertugas di Cabang 2 saja (Senin-Rabu 13:00-18:00)
    await db.insert('doctors', {
      'id': 2,
      'nama': 'dr. Kevin Mahendra',
      'spesialisasi': 'Laser Treatment',
      'branch_id': 2,
      'jadwal_praktik': 'Senin - Rabu, 13:00-18:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 2,
      'branch_id': 2,
      'hari': 1, // Senin
      'jam_mulai': '13:00',
      'jam_selesai': '18:00',
      'catatan': 'Senin, 13:00-18:00',
    });

    // Dokter 3 (Dr. Alya) bertugas di Cabang 3 (Senin-Selasa 09:00-14:00)
    await db.insert('doctors', {
      'id': 3,
      'nama': 'dr. Alya Permatasari',
      'spesialisasi': 'Dermatologi',
      'branch_id': 3,
      'jadwal_praktik': 'Senin - Selasa, 09:00-14:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 3,
      'branch_id': 3,
      'hari': 1, // Senin
      'jam_mulai': '09:00',
      'jam_selesai': '14:00',
      'catatan': 'Senin, 09:00-14:00',
    });

    // Dokter 4 (Dr. Limited) dengan jam praktik pendek (09:00 - 12:00) untuk uji batas waktu & durasi
    await db.insert('doctors', {
      'id': 4,
      'nama': 'dr. Limited Practice',
      'spesialisasi': 'Umum',
      'branch_id': 1,
      'jadwal_praktik': 'Senin, 09:00-12:00',
    });
    await db.insert('doctor_schedules', {
      'doctor_id': 4,
      'branch_id': 1,
      'hari': 1, // Senin
      'jam_mulai': '09:00',
      'jam_selesai': '12:00',
      'catatan': 'Senin, 09:00-12:00',
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Pengujian Wajib Booking Logika GlowClinic', () {
    // Skenario 1: Memilih cabang A hanya menampilkan dokter yang bertugas di cabang A
    test('1. Memilih cabang A hanya menampilkan dokter yang bertugas di cabang A', () async {
      // Cabang 1 (GlowClinic Pusat)
      final docsBranch1 = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 1,
      );

      final namesBranch1 = docsBranch1.map((d) => d['nama']).toList();
      expect(namesBranch1, contains('dr. Rina Aulia, Sp.KK'));
      expect(namesBranch1, contains('dr. Limited Practice'));
      // Dokter 2 (Kevin di Cabang 2) & Dokter 3 (Alya di Cabang 3) tidak boleh muncul
      expect(namesBranch1, isNot(contains('dr. Kevin Mahendra')));
      expect(namesBranch1, isNot(contains('dr. Alya Permatasari')));
    });

    // Skenario 2: Berpindah ke cabang B memperbarui daftar dokter
    test('2. Berpindah ke cabang B memperbarui daftar dokter', () async {
      // Berpindah ke Cabang 2 (Sleman)
      final docsBranch2 = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 2,
      );

      final namesBranch2 = docsBranch2.map((d) => d['nama']).toList();
      expect(namesBranch2, contains('dr. Kevin Mahendra'));
      expect(namesBranch2, contains('dr. Rina Aulia, Sp.KK')); // Rina juga bertugas di Cabang 2
      expect(namesBranch2, isNot(contains('dr. Limited Practice'))); // Hanya di cabang 1

      // Berpindah ke Cabang 3 (Bantul)
      final docsBranch3 = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 3,
      );
      final namesBranch3 = docsBranch3.map((d) => d['nama']).toList();
      expect(namesBranch3, contains('dr. Alya Permatasari'));
      expect(namesBranch3, isNot(contains('dr. Kevin Mahendra')));
    });

    // Skenario 3: Memilih tanggal berbeda memperbarui ketersediaan dokter
    test('3. Memilih tanggal berbeda memperbarui ketersediaan dokter', () async {
      // dr. Rina praktik di Cabang 1 pada hari Senin (hari 1) dan Selasa (hari 2), tetapi tidak pada hari Kamis (hari 4)
      final seninDate = DateTime(2026, 11, 2); // Senin (weekday == 1)
      final kamisDate = DateTime(2026, 11, 5); // Kamis (weekday == 4)

      final docsOnMonday = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 1,
        date: seninDate,
      );
      final namesOnMonday = docsOnMonday.map((d) => d['nama']).toList();
      expect(namesOnMonday, contains('dr. Rina Aulia, Sp.KK'));

      final docsOnThursday = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 1,
        date: kamisDate,
      );
      final namesOnThursday = docsOnThursday.map((d) => d['nama']).toList();
      expect(namesOnThursday, isNot(contains('dr. Rina Aulia, Sp.KK')));

      // Namun di Cabang 2, dr. Rina praktik pada hari Kamis!
      final docsBranch2Thursday = await DoctorScheduleService.getDoctorsForBranch(
        branchId: 2,
        date: kamisDate,
      );
      final namesBranch2Thursday = docsBranch2Thursday.map((d) => d['nama']).toList();
      expect(namesBranch2Thursday, contains('dr. Rina Aulia, Sp.KK'));
    });

    // Skenario 4: Slot yang sudah dipesan tidak bisa dipilih kembali
    test('4. Slot yang sudah dipesan tidak bisa dipilih kembali', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      // Pesan slot 09:00 WIB (02:00 UTC) untuk Dr. Rina, durasi 60 menit
      final bookedUtc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );

      await db.insert('bookings', {
        'user_id': 100,
        'doctor_id': 1,
        'branch_id': 1,
        'treatment_id': 1, // Facial Medis (60 menit)
        'waktu_utc': bookedUtc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'confirmed',
      });

      // Hitung slot waktu
      final slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 1,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );

      // Slot 09:00 harus 'Sudah dipesan' dan isAvailable == false
      final slot0900 = slots.firstWhere((s) => s.timeLabel == '09:00');
      expect(slot0900.isAvailable, isFalse);
      expect(slot0900.statusLabel, equals('Sudah dipesan'));

      // Slot 09:30 juga bertabrakan karena durasi treatment 60 menit (09:00 - 10:00)
      final slot0930 = slots.firstWhere((s) => s.timeLabel == '09:30');
      expect(slot0930.isAvailable, isFalse);
      expect(slot0930.statusLabel, equals('Sudah dipesan'));

      // Slot 10:00 harus bebas dan tersedia!
      final slot1000 = slots.firstWhere((s) => s.timeLabel == '10:00');
      expect(slot1000.isAvailable, isTrue);
      expect(slot1000.statusLabel, equals('Tersedia'));
    });

    // Skenario 5: Durasi treatment memengaruhi slot yang tersedia
    test('5. Durasi treatment memengaruhi slot yang tersedia', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin

      // Ada booking dokter pada pukul 10:00 - 11:00 WIB (durasi 60 menit)
      final booking1000Utc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 10,
        minute: 0,
        fromZone: 'WIB',
      );
      await db.insert('bookings', {
        'user_id': 101,
        'doctor_id': 1,
        'branch_id': 1,
        'treatment_id': 1,
        'waktu_utc': booking1000Utc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'pending',
      });

      // Jika treatment baru berdurasi 30 menit (misal: Konsultasi):
      // Slot 09:30 (09:30 - 10:00) BISA tersedia karena selesai tepat pukul 10:00 tanpa bertabrakan!
      final slots30Min = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 1,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 30,
        selectedZone: 'WIB',
      );
      final slot0930For30Min = slots30Min.firstWhere((s) => s.timeLabel == '09:30');
      expect(slot0930For30Min.isAvailable, isTrue);

      // Namun jika treatment baru berdurasi 60 menit (misal: Facial):
      // Slot 09:30 (09:30 - 10:30) BERTABRAKAN dengan booking 10:00 - 11:00!
      final slots60Min = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 1,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );
      final slot0930For60Min = slots60Min.firstWhere((s) => s.timeLabel == '09:30');
      expect(slot0930For60Min.isAvailable, isFalse);
    });

    // Skenario 6: Slot tidak melewati jam selesai praktik dokter
    test('6. Slot tidak melewati jam selesai praktik dokter', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      // dr. Limited Practice (id: 4) praktik dari 09:00 - 12:00
      // Jika treatment berdurasi 60 menit:
      // Slot terakhir yang valid adalah 11:00 (selesai 12:00).
      // Slot 11:30 TIDAK BOLEH ditawarkan karena treatment akan selesai pukul 12:30 (melewati jam praktik 12:00).
      final slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 4,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );

      final slotLabels = slots.map((s) => s.timeLabel).toList();
      expect(slotLabels, contains('09:00'));
      expect(slotLabels, contains('11:00'));
      expect(slotLabels, isNot(contains('11:30')));
      expect(slotLabels, isNot(contains('12:00')));
    });

    // Skenario 7: Booking yang dibatalkan tidak memblokir slot
    test('7. Booking yang dibatalkan tidak memblokir slot', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      final slot0900Utc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );

      // Masukkan booking dengan status 'cancelled'
      await db.insert('bookings', {
        'user_id': 102,
        'doctor_id': 1,
        'branch_id': 1,
        'waktu_utc': slot0900Utc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'cancelled',
      });

      // Masukkan booking dengan status 'batal'
      final slot1100Utc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 11,
        minute: 0,
        fromZone: 'WIB',
      );
      await db.insert('bookings', {
        'user_id': 103,
        'doctor_id': 1,
        'branch_id': 1,
        'waktu_utc': slot1100Utc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'batal',
      });

      final slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 1,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );

      final s0900 = slots.firstWhere((s) => s.timeLabel == '09:00');
      final s1100 = slots.firstWhere((s) => s.timeLabel == '11:00');

      expect(s0900.isAvailable, isTrue);
      expect(s0900.statusLabel, equals('Tersedia'));
      expect(s1100.isAvailable, isTrue);
      expect(s1100.statusLabel, equals('Tersedia'));
    });

    // Skenario 8: Dokter yang jadwalnya penuh menampilkan informasi yang sesuai
    test('8. Dokter yang jadwalnya penuh menampilkan informasi yang sesuai', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      // dr. Limited Practice (id: 4) praktik 09:00 - 12:00 (slot: 09:00, 09:30, 10:00, 10:30, 11:00)
      // Buat booking yang mengisi penuh rentang 09:00 - 12:00
      final slot0900Utc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );
      await db.insert('bookings', {
        'user_id': 201,
        'doctor_id': 4,
        'branch_id': 1,
        'waktu_utc': slot0900Utc.toIso8601String(),
        'durasi_menit': 180, // 3 jam penuh (09:00 - 12:00)
        'status': 'confirmed',
      });

      final slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 4,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );

      expect(slots.isNotEmpty, isTrue);
      // Semua slot harus tidak tersedia
      final allBooked = slots.every((s) => !s.isAvailable);
      expect(allBooked, isTrue);
    });

    // Skenario 9: Booking berhasil disimpan jika slot masih tersedia
    test('9. Booking berhasil disimpan jika slot masih tersedia', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      final slotUtc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );

      // Verifikasi awal slot tersedia
      final isFree = await DoctorScheduleService.isSlotAvailable(
        doctorId: 1,
        branchId: 1,
        startUtc: slotUtc,
        durationMinutes: 60,
      );
      expect(isFree, isTrue);

      // Simpan booking
      final id = await db.insert('bookings', {
        'user_id': 1,
        'doctor_id': 1,
        'branch_id': 1,
        'treatment_id': 1,
        'treatment_nama': 'Facial Medis',
        'waktu_utc': slotUtc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'pending',
      });
      expect(id, isPositive);

      final row = await db.query('bookings', where: 'id = ?', whereArgs: [id]);
      expect(row.isNotEmpty, isTrue);
      expect(row.first['doctor_id'], equals(1));
    });

    // Skenario 10: Booking ditolak jika slot sudah diambil oleh booking lain
    test('10. Booking ditolak jika slot sudah diambil oleh booking lain', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      final slotUtc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );

      // Masukkan booking pertama
      await db.insert('bookings', {
        'user_id': 1,
        'doctor_id': 1,
        'branch_id': 1,
        'waktu_utc': slotUtc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'pending',
      });

      // Cek ketersediaan untuk booking kedua pada slot yang sama
      final isAvailableNow = await DoctorScheduleService.isSlotAvailable(
        doctorId: 1,
        branchId: 1,
        startUtc: slotUtc,
        durationMinutes: 60,
      );
      expect(isAvailableNow, isFalse);

      // Cek ketersediaan untuk slot overlapping (09:30)
      final overlapUtc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 30,
        fromZone: 'WIB',
      );
      final isOverlapAvailable = await DoctorScheduleService.isSlotAvailable(
        doctorId: 1,
        branchId: 1,
        startUtc: overlapUtc,
        durationMinutes: 60,
      );
      expect(isOverlapAvailable, isFalse);
    });

    // Skenario 11: Jadwal setiap dokter dihitung secara independen
    test('11. Jadwal setiap dokter dihitung secara independen', () async {
      final mondayDate = DateTime(2026, 11, 2); // Senin
      final slot0900Utc = TimeZoneService.toUtc(
        date: mondayDate,
        hour: 9,
        minute: 0,
        fromZone: 'WIB',
      );

      // Booking dokter 1 (Dr. Rina) di Cabang 1 pada 09:00
      await db.insert('bookings', {
        'user_id': 1,
        'doctor_id': 1,
        'branch_id': 1,
        'waktu_utc': slot0900Utc.toIso8601String(),
        'durasi_menit': 60,
        'status': 'pending',
      });

      // Dokter 4 (Dr. Limited) juga praktik di Cabang 1 pada hari Senin 09:00
      // Slot 09:00 dokter 4 HARUS TETAP TERSEDIA karena jadwalnya independen!
      final doc4Slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 4,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );

      final doc4Slot0900 = doc4Slots.firstWhere((s) => s.timeLabel == '09:00');
      expect(doc4Slot0900.isAvailable, isTrue);
      expect(doc4Slot0900.statusLabel, equals('Tersedia'));

      // Sedangkan dokter 1 di jam 09:00 sudah dipesan
      final doc1Slots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: 1,
        branchId: 1,
        date: mondayDate,
        treatmentDurationMinutes: 60,
        selectedZone: 'WIB',
      );
      final doc1Slot0900 = doc1Slots.firstWhere((s) => s.timeLabel == '09:00');
      expect(doc1Slot0900.isAvailable, isFalse);
    });

    // Skenario 12: Aplikasi tetap berjalan tanpa merusak fitur yang sudah ada
    test('12. Aplikasi tetap berjalan tanpa merusak fitur konversi mata uang & zona waktu', () {
      // Test konversi mata uang
      expect(CurrencyService.activeCurrency.value, isNotNull);
      final rate = CurrencyService.getRate('USD');
      expect(rate, isPositive);
      final converted = CurrencyService.convertFromIdr(1000000, 'USD');
      expect(converted, equals(1000000 * rate));

      // Test konversi waktu antarzona
      final result = TimeZoneService.convert(
        fromZone: 'WIB',
        toZone: 'London',
        date: DateTime(2026, 6, 1),
        hour: 10,
        minute: 0,
      );
      expect(result.targetTz.hour, equals(4)); // Summer BST (UTC+1 vs UTC+7)
    });
  });
}
