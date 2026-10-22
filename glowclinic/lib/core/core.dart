
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as pth;
import 'package:sqflite/sqflite.dart';
export 'currency.dart';
import 'package:glowclinic/core/currency.dart';

late Database db;
const store = FlutterSecureStorage();

int? myId;
DateTime? sessionLastActivity;

/// Berubah setiap kali status sesi login berubah, agar SessionGuard ikut sinkron.
final ValueNotifier<int> sessionRevision = ValueNotifier<int>(0);


/// Preferensi biometrik disimpan secara aman pada perangkat.
const String _biometricEnabledKey = 'biometric_enabled';
const String _biometricFailuresKey = 'biometric_failures';
const String _biometricUserIdKey = 'biometric_uid';

Future<bool> isBiometricLoginEnabled() async {
  return await store.read(key: _biometricEnabledKey) == 'true';
}

Future<void> setBiometricLoginEnabled(bool enabled, {int? userId}) async {
  await store.write(
    key: _biometricEnabledKey,
    value: enabled ? 'true' : 'false',
  );

  if (enabled) {
    await store.write(key: _biometricFailuresKey, value: '0');
    final id = userId ?? myId;
    if (id != null) {
      await store.write(key: _biometricUserIdKey, value: '$id');
    }
  } else {
    await store.write(key: _biometricFailuresKey, value: '0');
  }
}

Future<int?> biometricLoginUserId() async {
  final raw = await store.read(key: _biometricUserIdKey);
  return int.tryParse(raw ?? '');
}

Future<int> recordBiometricFailure() async {
  final raw = await store.read(key: _biometricFailuresKey);
  final failures = (int.tryParse(raw ?? '') ?? 0) + 1;
  await store.write(key: _biometricFailuresKey, value: '$failures');

  if (failures >= 3) {
    await setBiometricLoginEnabled(false);
  }

  return failures;
}

Future<void> resetBiometricFailures() async {
  await store.write(key: _biometricFailuresKey, value: '0');
}

/// Naikkan nilainya agar daftar booking memuat ulang data.
final ValueNotifier<int> bookingRefresh = ValueNotifier<int>(0);

/// Naikkan nilainya agar ikon/badge notifikasi memuat ulang.
final ValueNotifier<int> notifTick = ValueNotifier<int>(0);

/// Akun staf demo. Dibuat otomatis saat aplikasi pertama dijalankan.
/// Ganti email/password ini sebelum rilis.
const kStaffEmail = 'staf@glowclinic.com';
const kStaffPassword = 'staf12345';

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

String newSalt() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

String hashPw(String salt, String pw) {
  var h = '$salt$pw';

  for (var i = 0; i < 1000; i++) {
    h = sha(h);
  }

  return h;
}

double dbl(dynamic x) => (x as num).toDouble();

void snack(BuildContext c, String t) {
  if (c.mounted) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Text(t)),
    );
  }
}

Future<List<Map<String, dynamic>>> qry(
  String sql, [
  List<Object?>? args,
]) async =>
    (await db.rawQuery(sql, args))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

const _schema = [
  "create table users(id integer primary key autoincrement, nama text, email text unique, no_hp text, role text not null default 'pasien', alergi text, tipe_kulit text, photo_path text, poin integer default 0, salt text, pass_hash text)",

  "create table branches(id integer primary key autoincrement, nama text, alamat text, lat real, lng real, jam_buka text)",

  "create table doctors("
      "id integer primary key autoincrement, "
      "nama text, "
      "spesialisasi text, "
      "branch_id integer, "
      "pendidikan text, "
      "pengalaman_tahun integer default 0, "
      "deskripsi text, "
      "jadwal_praktik text, "
      "photo_path text"
      ")",

  "create table treatments(id integer primary key autoincrement, nama text, kategori text, deskripsi text, durasi_menit integer, harga_idr integer)",

  "create table bookings(id integer primary key autoincrement, user_id integer, doctor_id integer, branch_id integer, treatment_id integer, treatment_nama text, waktu_utc text, durasi_menit integer default 60, status text default 'pending', status_bayar text default 'belum_bayar', metode_bayar text, kode_bayar text, total_idr integer, mata_uang text default 'IDR', kurs real default 1.0, total_bayar real, catatan_dokter text, spin_hadiah text, completed_at text, created_at text default current_timestamp)",

  "create table doctor_schedules(id integer primary key autoincrement, doctor_id integer, branch_id integer, hari integer, jam_mulai text, jam_selesai text, catatan text)",

  "create table record_photos(id integer primary key autoincrement, booking_id integer, tipe text, photo_path text, lux real, created_at text default current_timestamp)",

  "create table feedback(id integer primary key autoincrement, user_id integer, booking_id integer, rating integer, kesan text, saran text, created_at text default current_timestamp)",

  "create table notifications(id integer primary key autoincrement, user_id integer, judul text, isi text, tipe text default 'info', booking_id integer, dibaca integer default 0, shown integer default 0, waktu_utc text)",

  "create table blocks(id integer primary key autoincrement, idx integer, ts text, data text, prev_hash text, hash text)",

  "create table skin_journals(id integer primary key autoincrement, user_id integer not null, booking_id integer, tanggal text not null, kondisi_kulit text not null, keluhan text, catatan text, produk text, photo_path text, created_at text default current_timestamp, updated_at text default current_timestamp)",
];

const _treatments = [
  [
    'Facial Medis',
    'Facial',
    'Pembersihan dan perawatan kulit wajah',
    60,
    350000,
  ],
  [
    'Laser Rejuvenation',
    'Laser',
    'Peremajaan kulit dengan laser',
    45,
    1200000,
  ],
  [
    'Chemical Peeling',
    'Peeling',
    'Pengelupasan lapisan kulit terkendali',
    40,
    600000,
  ],
  [
    'Konsultasi Dokter',
    'Konsultasi',
    'Konsultasi kondisi kulit',
    20,
    150000,
  ],
];

/// Data dokter demo. Nama digunakan untuk mencegah data duplikat.

final List<Map<String, dynamic>> _doctors = [
  {
    'nama': 'dr. Rina Aulia, Sp.KK',
    'spesialisasi': 'Dermatologi',
    'branch_id': 1,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 8,
    'deskripsi': 'Berfokus pada pemeriksaan dan perawatan kesehatan kulit.',
    'jadwal_praktik': 'Senin - Rabu, 09:00-14:00',
    'photo_path': 'assets/images/rina.jpg',
  },
  {
    'nama': 'dr. Bima Pratama',
    'spesialisasi': 'Estetika',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Estetika',
    'pengalaman_tahun': 5,
    'deskripsi': 'Berfokus pada perawatan dan pemeliharaan estetika kulit.',
    'jadwal_praktik': 'Kamis - Sabtu, 10:00-16:00',
    'photo_path': 'assets/images/bima.jpg',
  },
  {
    'nama': 'dr. Nadia Putri',
    'spesialisasi': 'Dermatologi',
    'branch_id': 1,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 6,
    'deskripsi': 'Berfokus pada pemeriksaan kondisi kulit dan jerawat.',
    'jadwal_praktik': 'Senin - Selasa, 10:00-15:00',
    'photo_path': 'assets/images/nadia.jpg',
  },
  {
    'nama': 'dr. Aditya Prakoso',
    'spesialisasi': 'Estetika',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Estetika',
    'pengalaman_tahun': 7,
    'deskripsi': 'Berfokus pada perawatan estetika wajah.',
    'jadwal_praktik': 'Rabu - Kamis, 09:00-14:00',
    'photo_path': 'assets/images/aditya.jpg',
  },
  {
    'nama': 'dr. Salsabila Putri',
    'spesialisasi': 'Perawatan Kulit',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Perawatan Kulit',
    'pengalaman_tahun': 4,
    'deskripsi': 'Berfokus pada konsultasi dan perawatan kulit dasar.',
    'jadwal_praktik': 'Jumat - Sabtu, 10:00-16:00',
    'photo_path': 'assets/images/salsabila.jpg',
  },
  {
    'nama': 'dr. Kevin Mahendra',
    'spesialisasi': 'Laser Treatment',
    'branch_id': 2,
    'pendidikan': 'Kedokteran dan Pelatihan Laser',
    'pengalaman_tahun': 6,
    'deskripsi': 'Berfokus pada prosedur perawatan kulit berbasis laser.',
    'jadwal_praktik': 'Senin - Rabu, 13:00-18:00',
    'photo_path': 'assets/images/kevin.jpg',
  },
  {
    'nama': 'dr. Amanda Larasati',
    'spesialisasi': 'Dermatologi',
    'branch_id': 2,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 9,
    'deskripsi': 'Berfokus pada pemeriksaan dan kesehatan kulit wajah.',
    'jadwal_praktik': 'Selasa - Kamis, 09:00-15:00',
    'photo_path': 'assets/images/amanda.jpg',
  },
  {
    'nama': 'dr. Fajar Ramadhan',
    'spesialisasi': 'Estetika',
    'branch_id': 2,
    'pendidikan': 'Kedokteran dan Pelatihan Estetika',
    'pengalaman_tahun': 5,
    'deskripsi': 'Berfokus pada konsultasi perawatan estetika.',
    'jadwal_praktik': 'Kamis - Jumat, 10:00-16:00',
    'photo_path': 'assets/images/fajar.jpg',
  },
  {
    'nama': 'dr. Citra Maharani',
    'spesialisasi': 'Perawatan Kulit',
    'branch_id': 2,
    'pendidikan': 'Kedokteran dan Pelatihan Perawatan Kulit',
    'pengalaman_tahun': 3,
    'deskripsi': 'Berfokus pada perawatan dan pemeliharaan kulit.',
    'jadwal_praktik': 'Senin - Selasa, 09:00-13:00',
    'photo_path': 'assets/images/citra.jpg',
  },
  {
    'nama': 'dr. Rizky Ananda',
    'spesialisasi': 'Laser Treatment',
    'branch_id': 2,
    'pendidikan': 'Kedokteran dan Pelatihan Laser',
    'pengalaman_tahun': 7,
    'deskripsi': 'Berfokus pada prosedur estetika dan perawatan laser.',
    'jadwal_praktik': 'Jumat - Sabtu, 13:00-18:00',
    'photo_path': 'assets/images/rizky.jpg',
  },
  {
    'nama': 'dr. Alya Permatasari',
    'spesialisasi': 'Dermatologi',
    'branch_id': 3,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 5,
    'deskripsi':
        'Melayani konsultasi kesehatan kulit dan perawatan wajah.',
    'jadwal_praktik': 'Senin - Selasa, 09:00-14:00',
    'photo_path': 'assets/images/alya.jpg',
  },
  {
    'nama': 'dr. Dimas Saputra',
    'spesialisasi': 'Estetika',
    'branch_id': 3,
    'pendidikan': 'Kedokteran dan Pelatihan Estetika',
    'pengalaman_tahun': 6,
    'deskripsi':
        'Berfokus pada perawatan estetika dan pemeliharaan kulit.',
    'jadwal_praktik': 'Selasa - Rabu, 10:00-15:00',
    'photo_path': 'assets/images/dimas.jpg',
  },
  {
    'nama': 'dr. Shinta Maharani',
    'spesialisasi': 'Perawatan Kulit',
    'branch_id': 3,
    'pendidikan': 'Kedokteran dan Pelatihan Perawatan Kulit',
    'pengalaman_tahun': 4,
    'deskripsi':
        'Melayani pemeriksaan kulit dan rekomendasi perawatan sesuai kebutuhan.',
    'jadwal_praktik': 'Rabu - Kamis, 09:00-14:00',
    'photo_path': 'assets/images/shinta.jpg',
  },
  {
    'nama': 'dr. Reza Firmansyah',
    'spesialisasi': 'Laser Treatment',
    'branch_id': 3,
    'pendidikan': 'Kedokteran dan Pelatihan Laser',
    'pengalaman_tahun': 7,
    'deskripsi':
        'Berfokus pada konsultasi dan prosedur perawatan kulit berbasis laser.',
    'jadwal_praktik': 'Kamis - Jumat, 13:00-18:00',
    'photo_path': 'assets/images/reza.jpg',
  },
  {
    'nama': 'dr. Bella Anggraini',
    'spesialisasi': 'Dermatologi',
    'branch_id': 3,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 8,
    'deskripsi':
        'Melayani konsultasi kesehatan kulit dan perawatan wajah.',
    'jadwal_praktik': 'Jumat - Sabtu, 09:00-15:00',
    'photo_path': 'assets/images/bella.jpg',
  },
];

final List<Map<String, dynamic>> _seedDoctorSchedules = [
  // dr. Rina Aulia (Branch 1: Senin, Selasa, Rabu 09:00-14:00 | Branch 2: Kamis, Jumat 10:00-15:00)
  {'doctor_nama': 'dr. Rina Aulia, Sp.KK', 'branch_id': 1, 'hari': 1, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Senin, 09:00-14:00'},
  {'doctor_nama': 'dr. Rina Aulia, Sp.KK', 'branch_id': 1, 'hari': 2, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Selasa, 09:00-14:00'},
  {'doctor_nama': 'dr. Rina Aulia, Sp.KK', 'branch_id': 1, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Rina Aulia, Sp.KK', 'branch_id': 2, 'hari': 4, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Kamis, 10:00-15:00'},
  {'doctor_nama': 'dr. Rina Aulia, Sp.KK', 'branch_id': 2, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Jumat, 10:00-15:00'},

  // dr. Bima Pratama (Branch 1: Kamis, Jumat, Sabtu 10:00-16:00 | Branch 3: Senin, Selasa 09:00-14:00)
  {'doctor_nama': 'dr. Bima Pratama', 'branch_id': 1, 'hari': 4, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Kamis, 10:00-16:00'},
  {'doctor_nama': 'dr. Bima Pratama', 'branch_id': 1, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Jumat, 10:00-16:00'},
  {'doctor_nama': 'dr. Bima Pratama', 'branch_id': 1, 'hari': 6, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Sabtu, 10:00-16:00'},
  {'doctor_nama': 'dr. Bima Pratama', 'branch_id': 3, 'hari': 1, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Senin, 09:00-14:00'},
  {'doctor_nama': 'dr. Bima Pratama', 'branch_id': 3, 'hari': 2, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Selasa, 09:00-14:00'},

  // dr. Nadia Putri (Branch 1: Senin, Selasa 10:00-15:00 | Branch 2: Rabu, Kamis 09:00-14:00)
  {'doctor_nama': 'dr. Nadia Putri', 'branch_id': 1, 'hari': 1, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Senin, 10:00-15:00'},
  {'doctor_nama': 'dr. Nadia Putri', 'branch_id': 1, 'hari': 2, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Selasa, 10:00-15:00'},
  {'doctor_nama': 'dr. Nadia Putri', 'branch_id': 2, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Nadia Putri', 'branch_id': 2, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Kamis, 09:00-14:00'},

  // dr. Aditya Prakoso (Branch 1: Rabu, Kamis 09:00-14:00 | Branch 3: Jumat, Sabtu 10:00-15:00)
  {'doctor_nama': 'dr. Aditya Prakoso', 'branch_id': 1, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Aditya Prakoso', 'branch_id': 1, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Kamis, 09:00-14:00'},
  {'doctor_nama': 'dr. Aditya Prakoso', 'branch_id': 3, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Jumat, 10:00-15:00'},
  {'doctor_nama': 'dr. Aditya Prakoso', 'branch_id': 3, 'hari': 6, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Sabtu, 10:00-15:00'},

  // dr. Salsabila Putri (Branch 1: Jumat, Sabtu 10:00-16:00 | Branch 2: Senin, Selasa 10:00-16:00)
  {'doctor_nama': 'dr. Salsabila Putri', 'branch_id': 1, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Jumat, 10:00-16:00'},
  {'doctor_nama': 'dr. Salsabila Putri', 'branch_id': 1, 'hari': 6, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Sabtu, 10:00-16:00'},
  {'doctor_nama': 'dr. Salsabila Putri', 'branch_id': 2, 'hari': 1, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Senin, 10:00-16:00'},
  {'doctor_nama': 'dr. Salsabila Putri', 'branch_id': 2, 'hari': 2, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Selasa, 10:00-16:00'},

  // dr. Kevin Mahendra (Branch 2: Senin, Selasa, Rabu 13:00-18:00 | Branch 3: Kamis, Jumat 10:00-15:00)
  {'doctor_nama': 'dr. Kevin Mahendra', 'branch_id': 2, 'hari': 1, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Senin, 13:00-18:00'},
  {'doctor_nama': 'dr. Kevin Mahendra', 'branch_id': 2, 'hari': 2, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Selasa, 13:00-18:00'},
  {'doctor_nama': 'dr. Kevin Mahendra', 'branch_id': 2, 'hari': 3, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Rabu, 13:00-18:00'},
  {'doctor_nama': 'dr. Kevin Mahendra', 'branch_id': 3, 'hari': 4, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Kamis, 10:00-15:00'},
  {'doctor_nama': 'dr. Kevin Mahendra', 'branch_id': 3, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Jumat, 10:00-15:00'},

  // dr. Amanda Larasati (Branch 2: Selasa, Rabu, Kamis 09:00-15:00 | Branch 1: Jumat, Sabtu 09:00-14:00)
  {'doctor_nama': 'dr. Amanda Larasati', 'branch_id': 2, 'hari': 2, 'jam_mulai': '09:00', 'jam_selesai': '15:00', 'catatan': 'Selasa, 09:00-15:00'},
  {'doctor_nama': 'dr. Amanda Larasati', 'branch_id': 2, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '15:00', 'catatan': 'Rabu, 09:00-15:00'},
  {'doctor_nama': 'dr. Amanda Larasati', 'branch_id': 2, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '15:00', 'catatan': 'Kamis, 09:00-15:00'},
  {'doctor_nama': 'dr. Amanda Larasati', 'branch_id': 1, 'hari': 5, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Jumat, 09:00-14:00'},
  {'doctor_nama': 'dr. Amanda Larasati', 'branch_id': 1, 'hari': 6, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Sabtu, 09:00-14:00'},

  // dr. Fajar Ramadhan (Branch 2: Kamis, Jumat 10:00-16:00 | Branch 3: Senin, Selasa 10:00-15:00)
  {'doctor_nama': 'dr. Fajar Ramadhan', 'branch_id': 2, 'hari': 4, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Kamis, 10:00-16:00'},
  {'doctor_nama': 'dr. Fajar Ramadhan', 'branch_id': 2, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '16:00', 'catatan': 'Jumat, 10:00-16:00'},
  {'doctor_nama': 'dr. Fajar Ramadhan', 'branch_id': 3, 'hari': 1, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Senin, 10:00-15:00'},
  {'doctor_nama': 'dr. Fajar Ramadhan', 'branch_id': 3, 'hari': 2, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Selasa, 10:00-15:00'},

  // dr. Citra Maharani (Branch 2: Senin, Selasa 09:00-13:00 | Branch 1: Rabu, Kamis 10:00-15:00)
  {'doctor_nama': 'dr. Citra Maharani', 'branch_id': 2, 'hari': 1, 'jam_mulai': '09:00', 'jam_selesai': '13:00', 'catatan': 'Senin, 09:00-13:00'},
  {'doctor_nama': 'dr. Citra Maharani', 'branch_id': 2, 'hari': 2, 'jam_mulai': '09:00', 'jam_selesai': '13:00', 'catatan': 'Selasa, 09:00-13:00'},
  {'doctor_nama': 'dr. Citra Maharani', 'branch_id': 1, 'hari': 3, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Rabu, 10:00-15:00'},
  {'doctor_nama': 'dr. Citra Maharani', 'branch_id': 1, 'hari': 4, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Kamis, 10:00-15:00'},

  // dr. Rizky Ananda (Branch 2: Jumat, Sabtu 13:00-18:00 | Branch 3: Rabu, Kamis 13:00-17:00)
  {'doctor_nama': 'dr. Rizky Ananda', 'branch_id': 2, 'hari': 5, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Jumat, 13:00-18:00'},
  {'doctor_nama': 'dr. Rizky Ananda', 'branch_id': 2, 'hari': 6, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Sabtu, 13:00-18:00'},
  {'doctor_nama': 'dr. Rizky Ananda', 'branch_id': 3, 'hari': 3, 'jam_mulai': '13:00', 'jam_selesai': '17:00', 'catatan': 'Rabu, 13:00-17:00'},
  {'doctor_nama': 'dr. Rizky Ananda', 'branch_id': 3, 'hari': 4, 'jam_mulai': '13:00', 'jam_selesai': '17:00', 'catatan': 'Kamis, 13:00-17:00'},

  // dr. Alya Permatasari (Branch 3: Senin, Selasa 09:00-14:00 | Branch 1: Rabu, Kamis 09:00-14:00)
  {'doctor_nama': 'dr. Alya Permatasari', 'branch_id': 3, 'hari': 1, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Senin, 09:00-14:00'},
  {'doctor_nama': 'dr. Alya Permatasari', 'branch_id': 3, 'hari': 2, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Selasa, 09:00-14:00'},
  {'doctor_nama': 'dr. Alya Permatasari', 'branch_id': 1, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Alya Permatasari', 'branch_id': 1, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Kamis, 09:00-14:00'},

  // dr. Dimas Saputra (Branch 3: Selasa, Rabu 10:00-15:00 | Branch 2: Jumat, Sabtu 10:00-15:00)
  {'doctor_nama': 'dr. Dimas Saputra', 'branch_id': 3, 'hari': 2, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Selasa, 10:00-15:00'},
  {'doctor_nama': 'dr. Dimas Saputra', 'branch_id': 3, 'hari': 3, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Rabu, 10:00-15:00'},
  {'doctor_nama': 'dr. Dimas Saputra', 'branch_id': 2, 'hari': 5, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Jumat, 10:00-15:00'},
  {'doctor_nama': 'dr. Dimas Saputra', 'branch_id': 2, 'hari': 6, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Sabtu, 10:00-15:00'},

  // dr. Shinta Maharani (Branch 3: Rabu, Kamis 09:00-14:00 | Branch 1: Sabtu 10:00-15:00)
  {'doctor_nama': 'dr. Shinta Maharani', 'branch_id': 3, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Shinta Maharani', 'branch_id': 3, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Kamis, 09:00-14:00'},
  {'doctor_nama': 'dr. Shinta Maharani', 'branch_id': 1, 'hari': 6, 'jam_mulai': '10:00', 'jam_selesai': '15:00', 'catatan': 'Sabtu, 10:00-15:00'},

  // dr. Reza Firmansyah (Branch 3: Kamis, Jumat 13:00-18:00 | Branch 2: Senin, Selasa 13:00-17:00)
  {'doctor_nama': 'dr. Reza Firmansyah', 'branch_id': 3, 'hari': 4, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Kamis, 13:00-18:00'},
  {'doctor_nama': 'dr. Reza Firmansyah', 'branch_id': 3, 'hari': 5, 'jam_mulai': '13:00', 'jam_selesai': '18:00', 'catatan': 'Jumat, 13:00-18:00'},
  {'doctor_nama': 'dr. Reza Firmansyah', 'branch_id': 2, 'hari': 1, 'jam_mulai': '13:00', 'jam_selesai': '17:00', 'catatan': 'Senin, 13:00-17:00'},
  {'doctor_nama': 'dr. Reza Firmansyah', 'branch_id': 2, 'hari': 2, 'jam_mulai': '13:00', 'jam_selesai': '17:00', 'catatan': 'Selasa, 13:00-17:00'},

  // dr. Bella Anggraini (Branch 3: Jumat, Sabtu 09:00-15:00 | Branch 2: Rabu, Kamis 09:00-14:00)
  {'doctor_nama': 'dr. Bella Anggraini', 'branch_id': 3, 'hari': 5, 'jam_mulai': '09:00', 'jam_selesai': '15:00', 'catatan': 'Jumat, 09:00-15:00'},
  {'doctor_nama': 'dr. Bella Anggraini', 'branch_id': 3, 'hari': 6, 'jam_mulai': '09:00', 'jam_selesai': '15:00', 'catatan': 'Sabtu, 09:00-15:00'},
  {'doctor_nama': 'dr. Bella Anggraini', 'branch_id': 2, 'hari': 3, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Rabu, 09:00-14:00'},
  {'doctor_nama': 'dr. Bella Anggraini', 'branch_id': 2, 'hari': 4, 'jam_mulai': '09:00', 'jam_selesai': '14:00', 'catatan': 'Kamis, 09:00-14:00'},
];


Future<void> initDb() async {
  final path = pth.join(
    await getDatabasesPath(),
    'glowclinic.db',
  );

  db = await openDatabase(
    path,
    version: 8,
    onCreate: (database, version) async {
      for (final sql in _schema) {
        await database.execute(sql);
      }
    },
    onUpgrade: (database, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await database.execute(
          'ALTER TABLE doctors ADD COLUMN pendidikan TEXT',
        );
        await database.execute(
          'ALTER TABLE doctors ADD COLUMN pengalaman_tahun INTEGER DEFAULT 0',
        );
        await database.execute(
          'ALTER TABLE doctors ADD COLUMN deskripsi TEXT',
        );
        await database.execute(
          'ALTER TABLE doctors ADD COLUMN jadwal_praktik TEXT',
        );
        await database.execute(
          'ALTER TABLE doctors ADD COLUMN photo_path TEXT',
        );
      }
      if (oldVersion < 3) {
        // Simpan nama treatment di booking karena daftar treatment
        // berasal dari Supabase (ID-nya tidak sama dengan tabel lokal).
        await database.execute(
          'ALTER TABLE bookings ADD COLUMN treatment_nama TEXT',
        );
      }
      if (oldVersion < 4) {
        await database.execute(
          'CREATE TABLE IF NOT EXISTS notifications('
          'id integer primary key autoincrement, user_id integer, '
          'judul text, isi text, tipe text default \'info\', '
          'booking_id integer, dibaca integer default 0, '
          'shown integer default 0, waktu_utc text)',
        );
      }
      if (oldVersion < 5) {
        try {
          await database.execute(
            'ALTER TABLE bookings ADD COLUMN mata_uang TEXT DEFAULT "IDR"',
          );
        } catch (_) {}
        try {
          await database.execute(
            'ALTER TABLE bookings ADD COLUMN kurs REAL DEFAULT 1.0',
          );
        } catch (_) {}
        try {
          await database.execute(
            'ALTER TABLE bookings ADD COLUMN total_bayar REAL',
          );
        } catch (_) {}
      }
      if (oldVersion < 6) {
        try {
          await database.execute(
            'CREATE TABLE IF NOT EXISTS doctor_schedules('
            'id integer primary key autoincrement, '
            'doctor_id integer, '
            'branch_id integer, '
            'hari integer, '
            'jam_mulai text, '
            'jam_selesai text, '
            'catatan text)',
          );
        } catch (_) {}
        try {
          await database.execute(
            'ALTER TABLE bookings ADD COLUMN durasi_menit INTEGER DEFAULT 60',
          );
        } catch (_) {}
      }
      if (oldVersion < 7) {
        try {
          await database.execute(
            'CREATE TABLE IF NOT EXISTS skin_journals('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'user_id INTEGER NOT NULL, '
            'booking_id INTEGER, '
            'tanggal TEXT NOT NULL, '
            'kondisi_kulit TEXT NOT NULL, '
            'keluhan TEXT, '
            'catatan TEXT, '
            'produk TEXT, '
            'photo_path TEXT, '
            'created_at TEXT DEFAULT CURRENT_TIMESTAMP, '
            'updated_at TEXT DEFAULT CURRENT_TIMESTAMP)',
          );
        } catch (_) {}
      }
      if (oldVersion < 8) {
        try {
          await database.execute(
            'ALTER TABLE bookings ADD COLUMN completed_at TEXT',
          );
        } catch (_) {}
      }
    },
  );

  // Inisialisasi pengaturan mata uang dan kurs
  await CurrencyService.init();


  // Cabang demo dengan koordinat agar marker peta bisa dipilih.
  // Ganti alamat/koordinat ini dengan lokasi resmi sebelum rilis.
  final seedBranches = [
    {
      'nama': 'GlowClinic Pusat',
      'alamat': 'Area pusat Kota Yogyakarta (lokasi demo)',
      'lat': -7.797068,
      'lng': 110.370529,
      'jam_buka': '09:00-18:00',
    },
    {
      'nama': 'GlowClinic Sleman',
      'alamat': 'Area Sleman, Yogyakarta (lokasi demo)',
      'lat': -7.716165,
      'lng': 110.355614,
      'jam_buka': '09:00-18:00',
    },
    {
      'nama': 'GlowClinic Bantul',
      'alamat': 'Area Bantul, Yogyakarta (lokasi demo)',
      'lat': -7.888211,
      'lng': 110.328899,
      'jam_buka': '09:00-18:00',
    },
  ];
  for (final branch in seedBranches) {
    final existing = await db.query(
      'branches', columns: ['id'], where: 'nama = ?',
      whereArgs: [branch['nama']], limit: 1,
    );
    if (existing.isEmpty) await db.insert('branches', branch);
  }

  // Menambahkan data perawatan jika tabel masih kosong.
  final treatments = await db.query(
    'treatments',
    columns: ['id'],
    limit: 1,
  );

  if (treatments.isEmpty) {
    for (final treatment in _treatments) {
      await db.insert('treatments', {
        'nama': treatment[0],
        'kategori': treatment[1],
        'deskripsi': treatment[2],
        'durasi_menit': treatment[3],
        'harga_idr': treatment[4],
      });
    }
  }

  // Memasukkan atau memperbarui data 10 dokter.
  for (final doctor in _doctors) {
    final existing = await db.query(
      'doctors',
      columns: ['id'],
      where: 'nama = ?',
      whereArgs: [doctor['nama']],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('doctors', doctor);
    } else {
      await db.update(
        'doctors',
        doctor,
        where: 'nama = ?',
        whereArgs: [doctor['nama']],
      );
    }
  }

  // Sinkronkan jadwal praktik agar setiap dokter hanya terdaftar pada cabang
  // utama yang tercatat di doctors.branch_id. Ada 15 dokter dan 3 cabang:
  // pembagian dasar 5 dokter per cabang.
  try {
    await db.execute('''
      DELETE FROM doctor_schedules
      WHERE doctor_id IN (SELECT id FROM doctors)
        AND branch_id != (
          SELECT branch_id FROM doctors WHERE doctors.id = doctor_schedules.doctor_id
        )
    ''');
  } catch (e) {
    debugPrint('[DB] Sinkronisasi cabang jadwal dokter dilewati: $e');
  }

  for (final schedule in _seedDoctorSchedules) {
    final doctorName = schedule['doctor_nama'] as String;
    final scheduleBranchId = (schedule['branch_id'] as num).toInt();
    final doctorRows = await db.query(
      'doctors',
      columns: ['id', 'branch_id'],
      where: 'nama = ?',
      whereArgs: [doctorName],
      limit: 1,
    );
    if (doctorRows.isEmpty) continue;

    final doctorId = (doctorRows.first['id'] as num).toInt();
    final primaryBranchId = (doctorRows.first['branch_id'] as num?)?.toInt();
    if (primaryBranchId != scheduleBranchId) continue;

    final existingSchedule = await db.query(
      'doctor_schedules',
      columns: ['id'],
      where: 'doctor_id = ? AND branch_id = ? AND hari = ?',
      whereArgs: [doctorId, scheduleBranchId, schedule['hari']],
      limit: 1,
    );
    if (existingSchedule.isEmpty) {
      await db.insert('doctor_schedules', {
        'doctor_id': doctorId,
        'branch_id': scheduleBranchId,
        'hari': schedule['hari'],
        'jam_mulai': schedule['jam_mulai'],
        'jam_selesai': schedule['jam_selesai'],
        'catatan': schedule['catatan'],
      });
    }
  }

  // Akun staf demo (login tidak lagi membuat akun pasien baru).
  final staff = await db.query(
    'users',
    where: 'lower(trim(email)) in (?, ?)',
    whereArgs: [kStaffEmail, 'staff@glowclinic.com'],
  );

  if (staff.isEmpty) {
    final salt = newSalt();
    await db.insert('users', {
      'nama': 'Staf GlowClinic',
      'email': kStaffEmail,
      'role': 'staf',
      'salt': salt,
      'pass_hash': hashPw(salt, kStaffPassword),
    });
    debugPrint('[DB] Akun staf demo baru dibuat ($kStaffEmail).');
  } else {
    // Sinkronkan hash password akun staf demo agar selalu konsisten dengan kStaffPassword
    // mengatasi masalah database lama di HP fisik yang masih menyimpan hash password lama
    for (final s in staff) {
      final salt = (s['salt']?.toString().isNotEmpty ?? false)
          ? s['salt'].toString()
          : newSalt();
      await db.update(
        'users',
        {
          'role': 'staf',
          'salt': salt,
          'pass_hash': hashPw(salt, kStaffPassword),
        },
        where: 'id = ?',
        whereArgs: [s['id']],
      );
      debugPrint('[DB] Akun staf demo disinkronkan (${s['email']}).');
    }
  }
}

