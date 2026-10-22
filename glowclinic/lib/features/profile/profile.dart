import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/settings/settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _PF();
}

class _PF extends State<ProfileScreen> {
  final nama = TextEditingController();
  final hp = TextEditingController();
  final kulit = TextEditingController();
  final alergi = TextEditingController();

  Map<String, dynamic> u = {};
  bool loading = true;
  bool saving = false;
  bool pickingPhoto = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    nama.dispose();
    hp.dispose();
    kulit.dispose();
    alergi.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final rows = await qry('select * from users where id = ?', [myId]);

      if (rows.isEmpty) {
        if (!mounted) return;
        setState(() {
          error = 'Data profil tidak ditemukan.';
          loading = false;
        });
        return;
      }

      final row = Map<String, dynamic>.from(rows.first);

      if (!mounted) return;

      nama.text = row['nama']?.toString() ?? '';
      hp.text = row['no_hp']?.toString() ?? '';
      kulit.text = row['tipe_kulit']?.toString() ?? '';
      alergi.text = row['alergi']?.toString() ?? '';

      setState(() {
        u = row;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Gagal memuat profil. Periksa koneksi database.';
        loading = false;
      });
    }
  }

  Future<void> photo() async {
    if (pickingPhoto) return;

    setState(() {
      pickingPhoto = true;
    });

    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (x == null || !mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/profile_${myId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await File(x.path).copy(path);

      await db.update(
        'users',
        {'photo_path': path},
        where: 'id = ?',
        whereArgs: [myId],
      );

      if (!mounted) return;

      setState(() {
        u = {...u, 'photo_path': path};
      });

      snack(context, 'Foto profil berhasil diperbarui.');
    } catch (_) {
      if (mounted) {
        snack(context, 'Gagal memperbarui foto profil.');
      }
    } finally {
      if (mounted) {
        setState(() {
          pickingPhoto = false;
        });
      }
    }
  }

  Future<void> confirmLogout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login kembali untuk masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yes == true && mounted) {
      await logout(context);
    }
  }

  Future<void> save() async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      await db.update(
        'users',
        {
          'nama': nama.text.trim(),
          'no_hp': hp.text.trim(),
          'tipe_kulit': kulit.text.trim(),
          'alergi': alergi.text.trim(),
        },
        where: 'id = ?',
        whereArgs: [myId],
      );

      if (!mounted) return;

      setState(() {
        u = {
          ...u,
          'nama': nama.text.trim(),
          'no_hp': hp.text.trim(),
          'tipe_kulit': kulit.text.trim(),
          'alergi': alergi.text.trim(),
        };
      });

      snack(context, 'Profil berhasil disimpan.');
    } catch (_) {
      if (mounted) {
        snack(context, 'Gagal menyimpan profil.');
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    final photoPath = u['photo_path']?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF641F35),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF641F35).withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: pickingPhoto ? null : photo,
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  backgroundImage: photoPath != null &&
                          photoPath.isNotEmpty &&
                          File(photoPath).existsSync()
                      ? FileImage(File(photoPath))
                      : null,
                  child: pickingPhoto
                      ? const CircularProgressIndicator(color: Colors.white)
                      : photoPath == null || photoPath.isEmpty
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.white,
                            )
                          : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profil kamu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Kelola data untuk pengalaman treatment yang lebih personal.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✦  ${u['poin'] ?? 0} poin loyalitas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Informasi pribadi',
          style: TextStyle(
            color: Color(0xFF49343B),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nama,
          decoration: const InputDecoration(
            labelText: 'Nama lengkap',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: hp,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor telepon',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Preferensi kulit',
          style: TextStyle(
            color: Color(0xFF49343B),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: kulit,
          decoration: const InputDecoration(
            labelText: 'Tipe kulit',
            hintText: 'Berminyak, kering, kombinasi, sensitif',
            prefixIcon: Icon(Icons.spa_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: alergi,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alergi atau sensitivitas',
            prefixIcon: Icon(Icons.health_and_safety_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Simpan perubahan'),
        ),
        const SizedBox(height: 28),
        const Text(
          'Akun',
          style: TextStyle(
            color: Color(0xFF49343B),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Pengaturan'),
                subtitle: const Text('Notifikasi, lokasi, mata uang'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFD85F89),
                ),
                title: const Text(
                  'Keluar dari akun',
                  style: TextStyle(color: Color(0xFFD85F89)),
                ),
                onTap: confirmLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
