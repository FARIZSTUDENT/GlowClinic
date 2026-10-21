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
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: GestureDetector(
            onTap: pickingPhoto ? null : photo,
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  photoPath != null &&
                      photoPath.isNotEmpty &&
                      File(photoPath).existsSync()
                  ? FileImage(File(photoPath))
                  : null,
              child: pickingPhoto
                  ? const CircularProgressIndicator()
                  : photoPath == null || photoPath.isEmpty
                  ? const Icon(Icons.add_a_photo)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('Poin loyalitas: ${u['poin'] ?? 0}')),
        const SizedBox(height: 16),
        TextField(
          controller: nama,
          decoration: const InputDecoration(labelText: 'Nama'),
        ),
        TextField(
          controller: hp,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'No. HP'),
        ),
        TextField(
          controller: kulit,
          decoration: const InputDecoration(
            labelText: 'Tipe kulit (berminyak/kering/sensitif)',
          ),
        ),
        TextField(
          controller: alergi,
          decoration: const InputDecoration(labelText: 'Alergi'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Pengaturan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Color(0xFFD85F89)),
          title: const Text(
            'Keluar',
            style: TextStyle(color: Color(0xFFD85F89)),
          ),
          onTap: confirmLogout,
        ),
      ],
    );
  }
}
