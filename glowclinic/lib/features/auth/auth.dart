
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/home/patient_home.dart';
import 'package:glowclinic/features/home/staff_home.dart';

// Membuat sesi login
Future<void> startSession(int id) async {
  myId = id;

  await store.write(key: 'uid', value: '$id');
  await store.write(
    key: 'exp',
    value: '${DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch}',
  );
  await store.write(key: 'tok', value: newSalt());
}

// Membaca sesi login dengan penanganan error
Future<bool> loadSession() async {
  try {
    final u = await store.read(key: 'uid');
    final e = await store.read(key: 'exp');

    if (u == null || e == null) {
      return false;
    }

    final expiry = int.tryParse(e);
    final userId = int.tryParse(u);

    if (expiry == null ||
        userId == null ||
        expiry < DateTime.now().millisecondsSinceEpoch) {
      await clearSession();
      return false;
    }

    myId = userId;
    return true;
  } catch (e) {
    // Sesi tidak bisa dibaca atau didekripsi.
    try {
      await clearSession();
    } catch (_) {
      // Penghapusan sesi mungkin gagal jika storage rusak.
    }

    myId = null;
    return false;
  }
}

// Menghapus sesi login
Future<void> clearSession() async {
  myId = null;

  for (final k in ['uid', 'exp', 'tok']) {
    await store.delete(key: k);
  }
}

// Mengarahkan pengguna ke halaman sesuai role
Future<void> goHome(BuildContext c) async {
  final r = await qry('select role from users where id=?', [myId]);

  if (!c.mounted) return;

  if (r.isEmpty) {
    try {
      await clearSession();
    } catch (_) {}

    if (!c.mounted) return;

    Navigator.pushAndRemoveUntil(
      c,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return;
  }

  final role = '${r.first['role']}'.trim().toLowerCase();

  Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(
      builder: (_) =>
          ['staf', 'staff', 'admin'].contains(role)
              ? const StaffHome()
              : const PatientHome(),
    ),
    (_) => false,
  );
}

// Logout
Future<void> logout(BuildContext c) async {
  try {
    await clearSession();
  } catch (_) {
    myId = null;
  }

  if (!c.mounted) return;

  Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

// ---------- Gate: sesi + biometrik ----------

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _G();
}

class _G extends State<Gate> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        run();
      }
    });
  }

  Future<void> run() async {
    // Periksa sesi login.
    final validSession = await loadSession();

    if (!mounted) return;

    if (!validSession) {
      _login();
      return;
    }

    // Periksa pengaturan biometrik.
    String? bio;

    try {
      bio = await store.read(key: 'bio');
    } catch (_) {
      // Jika pembacaan storage gagal, minta login ulang.
      try {
        await clearSession();
      } catch (_) {}

      if (mounted) _login();
      return;
    }

    if (!mounted) return;

    // Jika biometrik aktif, lakukan verifikasi.
    if (bio == '1') {
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
          // Jika autentikasi gagal, lanjutkan percobaan berikutnya.
        }
      }

      try {
        await clearSession();
      } catch (_) {}

      if (mounted) _login();
      return;
    }

    // Jika biometrik tidak aktif, langsung menuju halaman utama.
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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
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
      final r = await qry(
        'select 1 from users where lower(trim(email)) = ?',
        [email],
      );

      if (!mounted) return;

      setState(() {
        step = r.isNotEmpty ? 1 : 2;
        err = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          err =
              'Tidak dapat memeriksa akun. Pastikan database siap lalu coba lagi.';
        });
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
        // Login pengguna yang sudah terdaftar.
        final r = await qry(
          'select * from users where lower(trim(email)) = ?',
          [email],
        );

        if (r.isEmpty ||
            r.first['salt'] == null ||
            r.first['pass_hash'] == null ||
            hashPw('${r.first['salt']}', pw.text) !=
                '${r.first['pass_hash']}') {
          throw Exception('Email atau password salah');
        }

        id = r.first['id'] as int;
      } else {
        // Registrasi pasien baru.
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
        setState(() {
          err = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    const primary = Color(0xFFD85F89);
    const ink = Color(0xFF513B45);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE2EB),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      size: 42,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'GlowClinic',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Perawatan kulit dimulai dari sini.',
                    style: TextStyle(
                      color: Color(0xFF927783),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF4DDE5),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12A64C70),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          step == 0
                              ? 'Selamat datang'
                              : step == 1
                                  ? 'Masuk ke akunmu'
                                  : 'Buat akun pasien',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          step == 0
                              ? 'Masukkan email untuk melanjutkan.'
                              : step == 1
                                  ? 'Masukkan password akun GlowClinic.'
                                  : 'Email belum terdaftar. Lengkapi data berikut.',
                          style: const TextStyle(
                            color: Color(0xFF927783),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: em,
                          enabled: step == 0 && !busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            filled: true,
                            fillColor: const Color(0xFFFFFAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        if (step == 2) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: nm,
                            enabled: !busy,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            decoration: InputDecoration(
                              labelText: 'Nama lengkap',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFFFAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                        if (step > 0) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: pw,
                            enabled: !busy,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: step == 1
                                ? const [AutofillHints.password]
                                : const [AutofillHints.newPassword],
                            onSubmitted: (_) {
                              if (!busy) submit();
                            },
                            decoration: InputDecoration(
                              labelText: step == 2
                                  ? 'Buat password (min. 6 karakter)'
                                  : 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFFFAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                        if (err != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFB4234D),
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    err!,
                                    style: const TextStyle(
                                      color: Color(0xFFB4234D),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : (step == 0 ? next : submit),
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    step == 0
                                        ? 'Lanjutkan'
                                        : step == 1
                                            ? 'Masuk'
                                            : 'Buat akun',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                                      nm.clear();
                                    });
                                  },
                            child: const Text(
                              'Gunakan email lain',
                              style: TextStyle(color: primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Akun staf dibuat oleh administrator klinik.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF927783),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
