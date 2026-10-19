
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as pth;
import 'package:sqflite/sqflite.dart';

late Database db;
const store = FlutterSecureStorage();

int? myId;

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

  "create table bookings(id integer primary key autoincrement, user_id integer, doctor_id integer, branch_id integer, treatment_id integer, waktu_utc text, status text default 'pending', status_bayar text default 'belum_bayar', metode_bayar text, kode_bayar text, total_idr integer, catatan_dokter text, spin_hadiah text, created_at text default current_timestamp)",

  "create table record_photos(id integer primary key autoincrement, booking_id integer, tipe text, photo_path text, lux real, created_at text default current_timestamp)",

  "create table feedback(id integer primary key autoincrement, user_id integer, booking_id integer, rating integer, kesan text, saran text, created_at text default current_timestamp)",

  "create table blocks(id integer primary key autoincrement, idx integer, ts text, data text, prev_hash text, hash text)",
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
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Laser',
    'pengalaman_tahun': 6,
    'deskripsi': 'Berfokus pada prosedur perawatan kulit berbasis laser.',
    'jadwal_praktik': 'Senin - Rabu, 13:00-18:00',
    'photo_path': 'assets/images/kevin.jpg',
  },
  {
    'nama': 'dr. Amanda Larasati',
    'spesialisasi': 'Dermatologi',
    'branch_id': 1,
    'pendidikan': 'Spesialis Dermatologi',
    'pengalaman_tahun': 9,
    'deskripsi': 'Berfokus pada pemeriksaan dan kesehatan kulit wajah.',
    'jadwal_praktik': 'Selasa - Kamis, 09:00-15:00',
    'photo_path': 'assets/images/amanda.jpg',
  },
  {
    'nama': 'dr. Fajar Ramadhan',
    'spesialisasi': 'Estetika',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Estetika',
    'pengalaman_tahun': 5,
    'deskripsi': 'Berfokus pada konsultasi perawatan estetika.',
    'jadwal_praktik': 'Kamis - Jumat, 10:00-16:00',
    'photo_path': 'assets/images/fajar.jpg',
  },
  {
    'nama': 'dr. Citra Maharani',
    'spesialisasi': 'Perawatan Kulit',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Perawatan Kulit',
    'pengalaman_tahun': 3,
    'deskripsi': 'Berfokus pada perawatan dan pemeliharaan kulit.',
    'jadwal_praktik': 'Senin - Selasa, 09:00-13:00',
    'photo_path': 'assets/images/citra.jpg',
  },
  {
    'nama': 'dr. Rizky Ananda',
    'spesialisasi': 'Laser Treatment',
    'branch_id': 1,
    'pendidikan': 'Kedokteran dan Pelatihan Laser',
    'pengalaman_tahun': 7,
    'deskripsi': 'Berfokus pada prosedur estetika dan perawatan laser.',
    'jadwal_praktik': 'Jumat - Sabtu, 13:00-18:00',
    'photo_path': 'assets/images/rizky.jpg',
  },
];


Future<void> initDb() async {
  final path = pth.join(
    await getDatabasesPath(),
    'glowclinic.db',
  );

  db = await openDatabase(
    path,
    version: 2,
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
    },
  );


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
}

