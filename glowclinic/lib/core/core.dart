import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as pth;
import 'package:sqflite/sqflite.dart';

late Database db;
const store = FlutterSecureStorage();

int? myId; // ID pengguna yang sedang login

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

String newSalt() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// Hash password: SHA-256(salt + password) diulang 1000x
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
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));
  }
}

/// Query yang mengembalikan salinan map yang bisa diubah
Future<List<Map<String, dynamic>>> qry(
  String sql, [
  List<Object?>? args,
]) async => (await db.rawQuery(
  sql,
  args,
)).map((e) => Map<String, dynamic>.from(e)).toList();

const _schema = [
  "create table users(id integer primary key autoincrement, nama text, email text unique, no_hp text, role text not null default 'pasien', alergi text, tipe_kulit text, photo_path text, poin integer default 0, salt text, pass_hash text)",
  "create table branches(id integer primary key autoincrement, nama text, alamat text, lat real, lng real, jam_buka text)",
  "create table doctors(id integer primary key autoincrement, nama text, spesialisasi text, branch_id integer)",
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
  ['Laser Rejuvenation', 'Laser', 'Peremajaan kulit dengan laser', 45, 1200000],
  [
    'Chemical Peeling',
    'Peeling',
    'Pengelupasan lapisan kulit terkendali',
    40,
    600000,
  ],
  ['Konsultasi Dokter', 'Konsultasi', 'Konsultasi kondisi kulit', 20, 150000],
];

Future<void> initDb() async {
  db = await openDatabase(
    pth.join(await getDatabasesPath(), 'glowclinic.db'),
    version: 1,
    onCreate: (d, v) async {
      for (final s in _schema) {
        await d.execute(s);
      }

      // Akun staf bawaan untuk demo.
      // Ganti password sebelum aplikasi digunakan secara nyata.
      final salt = newSalt();

      await d.insert('users', {
        'nama': 'Staf GlowClinic',
        'email': 'staf@glowclinic.com',
        'role': 'staf',
        'salt': salt,
        'pass_hash': hashPw(salt, 'staf123'),
      });

      await d.insert('branches', {
        'nama': 'GlowClinic Pusat',
        'alamat': 'Jl. Contoh No.1',
        'lat': -6.2,
        'lng': 106.8,
        'jam_buka': '09:00-20:00',
      });

      await d.insert('doctors', {
        'nama': 'dr. Rina Aulia, Sp.KK',
        'spesialisasi': 'Dermatologi',
        'branch_id': 1,
      });

      await d.insert('doctors', {
        'nama': 'dr. Bima Pratama',
        'spesialisasi': 'Estetika',
        'branch_id': 1,
      });

      for (final t in _treatments) {
        await d.insert('treatments', {
          'nama': t[0],
          'kategori': t[1],
          'deskripsi': t[2],
          'durasi_menit': t[3],
          'harga_idr': t[4],
        });
      }
    },
  );
}
