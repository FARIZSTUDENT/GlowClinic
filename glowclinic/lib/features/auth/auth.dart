import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/home/patient_home.dart';
import 'package:glowclinic/features/home/staff_home.dart';

Future<void> startSession(int id) async {
  myId = id;

  await store.write(key: 'uid', value: '$id');
  await store.write(
    key: 'exp',
    value:
        '${DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch}',
  );
  await store.write(key: 'tok', value: newSalt());
}

Future<bool> loadSession() async {
  final u = await store.read(key: 'uid');
  final e = await store.read(key: 'exp');

  if (u == null || e == null) {
    return false;
  }

  final expiry = int.tryParse(e);
  if (expiry == null || expiry < DateTime.now().millisecondsSinceEpoch) {
    return false;
  }

  myId = int.tryParse(u);
  return myId != null;
}

Future<void> clearSession() async {
  myId = null;

  for (final k in ['uid', 'exp', 'tok']) {
    await store.delete(key: k);
  }
}

Future<void> goHome(BuildContext c) async {
  final r = await qry('select role from users where id=?', [myId]);

  if (!c.mounted) return;

  if (r.isEmpty) {
    await clearSession();

    if (!c.mounted) return;

    Navigator.pushAndRemoveUntil(
      c,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return;
  }

  Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(
      builder: (_) =>
          r.first['role'] == 'staf' ? const StaffHome() : const PatientHome(),
    ),
    (_) => false,
  );
}

Future<void> logout(BuildContext c) async {
  await clearSession(); // Pengaturan biometrik tetap tersimpan.

  if (!c.mounted) return;

  Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

// ---------- Gate: sesi + biometrik (gagal 2x -> login) ----------

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _G();
}

class _G extends State<Gate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  Future<void> run() async {
    if (!await loadSession()) {
      if (mounted) _login();
      return;
    }

    if (await store.read(key: 'bio') == '1') {
      final la = LocalAuthentication();

      for (var i = 0; i < 2; i++) {
        try {
          final authenticated = await la.authenticate(
            localizedReason: 'Verifikasi untuk masuk',
          );

          if (!mounted) return;

          if (authenticated) {
            await goHome(context);
            return;
          }
        } catch (_) {
          if (!mounted) return;
        }
      }

      await clearSession();

      if (mounted) _login();
      return;
    }

    if (mounted) {
      await goHome(context);
    }
  }

  void _login() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext c) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ---------- Login: email -> password / register ----------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LS();
}

class _LS extends State<LoginScreen> {
  final em = TextEditingController();
  final pw = TextEditingController();
  final nm = TextEditingController();

  int step = 0; // 0 email, 1 password, 2 register
  String? err;
  bool busy = false;

  String get email => em.text.trim().toLowerCase();

  @override
  void dispose() {
    em.dispose();
    pw.dispose();
    nm.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (!email.contains('@')) {
      setState(() => err = 'Email tidak valid');
      return;
    }

    setState(() {
      busy = true;
      err = null;
    });

    try {
      final r = await qry('select 1 from users where lower(email)=?', [email]);

      if (!mounted) return;

      setState(() {
        step = r.isNotEmpty ? 1 : 2;
        err = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => err = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      err = null;
    });

    try {
      int id;

      if (step == 1) {
        final r = await qry('select * from users where lower(email)=?', [
          email,
        ]);

        if (r.isEmpty ||
            hashPw(r.first['salt'], pw.text) != r.first['pass_hash']) {
          throw Exception('Email atau password salah');
        }

        id = r.first['id'] as int;
      } else {
        if (nm.text.trim().isEmpty) {
          throw Exception('Nama wajib diisi');
        }

        if (pw.text.length < 6) {
          throw Exception('Password minimal 6 karakter');
        }

        final salt = newSalt();

        id = await db.insert('users', {
          'nama': nm.text.trim(),
          'email': email,
          'role': 'pasien',
          'salt': salt,
          'pass_hash': hashPw(salt, pw.text),
        });
      }

      await startSession(id);

      if (!mounted) return;

      await goHome(context);
    } catch (e) {
      if (mounted) {
        setState(() => err = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'GlowClinic',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: em,
                enabled: step == 0 && !busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (step == 2)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Email belum terdaftar. Buat akun pasien:'),
                ),
              if (step == 2)
                TextField(
                  controller: nm,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Nama lengkap'),
                ),
              if (step > 0)
                TextField(
                  controller: pw,
                  enabled: !busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: step == 2 ? 'Buat password' : 'Password',
                  ),
                ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(err!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : (step == 0 ? next : submit),
                child: Text(
                  step == 0
                      ? 'Lanjut'
                      : step == 1
                      ? 'Masuk'
                      : 'Daftar',
                ),
              ),
              if (step > 0)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            step = 0;
                            err = null;
                            pw.clear();
                          });
                        },
                  child: const Text('Ganti email'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
