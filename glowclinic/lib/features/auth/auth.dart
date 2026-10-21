
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/home/patient_home.dart';
import 'package:glowclinic/features/home/staff_home.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/features/notif/notif.dart';

// Membuat sesi login
Future<void> startSession(int id) async {
  myId = id;

  await store.write(key: 'uid', value: '$id');
  await store.write(
    key: 'exp',
    value: '${DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch}',
  );
  await store.write(key: 'tok', value: newSalt());

  // Akun ini diingat agar login berikutnya cukup dengan biometrik.
  await store.write(key: 'last_uid', value: '$id');
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

// Lupakan akun terakhir (untuk "Gunakan akun lain")
Future<void> forgetAccount() async {
  try {
    await clearSession();
    await store.delete(key: 'last_uid');
  } catch (_) {
    myId = null;
  }
}

// Logout
Future<void> logout(BuildContext c) async {
  stopNotifWatcher();

  try {
    await cancelPromos();
  } catch (_) {}

  try {
    await clearSession();
  } catch (_) {
    myId = null;
  }

  if (!c.mounted) return;

  Navigator.pushAndRemoveUntil(
    c,
    MaterialPageRoute(builder: (_) => const Gate()),
    (_) => false,
  );
}

// ---------- Gate: biometrik wajib, password setelah 3x gagal ----------

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _G();
}

class _G extends State<Gate> {
  static const _maxFails = 3;
  static const _primary = Color(0xFFD85F89);
  static const _ink = Color(0xFF513B45);

  final _la = LocalAuthentication();
  final _pw = TextEditingController();

  int? _uid;
  String _name = '';
  int _fails = 0;
  bool _checking = true;
  bool _busy = false;
  bool _askPassword = false;
  String? _note;
  String? _err;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _login() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _start() async {
    int? id;

    try {
      final u = await store.read(key: 'uid') ?? await store.read(key: 'last_uid');
      id = int.tryParse(u ?? '');
    } catch (_) {
      id = null;
    }

    if (id == null) {
      _login();
      return;
    }

    final rows = await qry('select id, nama from users where id = ?', [id]);

    if (!mounted) return;

    if (rows.isEmpty) {
      await forgetAccount();
      _login();
      return;
    }

    bool available = false;

    try {
      available = await _la.isDeviceSupported() &&
          (await _la.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      available = false;
    }

    if (!mounted) return;

    setState(() {
      _uid = id;
      _name = '${rows.first['nama'] ?? ''}'.trim();
      _checking = false;

      if (!available) {
        _askPassword = true;
        _note = 'Biometrik belum tersedia atau belum terdaftar di perangkat '
            'ini. Masuk dengan password.';
      }
    });

    if (available) {
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (_busy || _askPassword || _uid == null) return;

    setState(() {
      _busy = true;
      _err = null;
    });

    var ok = false;

    try {
      ok = await _la.authenticate(
        localizedReason: 'Verifikasi sidik jari/wajah untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!ok) _fails++;
    } on PlatformException catch (e) {
      const fatal = [
        'LockedOut',
        'PermanentlyLockedOut',
        'NotAvailable',
        'NotEnrolled',
        'PasscodeNotSet',
      ];

      _fails = fatal.contains(e.code) ? _maxFails : _fails + 1;
    } catch (_) {
      _fails++;
    }

    if (!mounted) return;

    if (ok) {
      await _enter();
      return;
    }

    setState(() {
      _busy = false;

      if (_fails >= _maxFails) {
        _askPassword = true;
        _note = 'Biometrik gagal $_maxFails kali. '
            'Masukkan password untuk melanjutkan.';
      }
    });
  }

  Future<void> _enter() async {
    try {
      await startSession(_uid!);

      if (!mounted) return;

      await goHome(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'Gagal masuk. Coba lagi.';
        });
      }
    }
  }

  Future<void> _submitPassword() async {
    if (_busy || _uid == null) return;

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final r = await qry('select * from users where id = ?', [_uid]);

      final valid = r.isNotEmpty &&
          r.first['salt'] != null &&
          r.first['pass_hash'] != null &&
          hashPw('${r.first['salt']}', _pw.text) == '${r.first['pass_hash']}';

      if (!valid) {
        if (mounted) {
          setState(() {
            _busy = false;
            _err = 'Password salah';
          });
        }
        return;
      }

      await _enter();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'Gagal memeriksa password. Coba lagi.';
        });
      }
    }
  }

  Future<void> _otherAccount() async {
    await forgetAccount();
    _login();
  }

  @override
  Widget build(BuildContext c) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.spa_rounded, size: 52, color: _primary),
                  const SizedBox(height: 12),
                  const Text(
                    'GlowClinic',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _name.isEmpty ? 'Selamat datang kembali' : 'Halo, $_name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF927783)),
                  ),
                  const SizedBox(height: 32),
                  if (!_askPassword) ...[
                    Center(
                      child: InkWell(
                        onTap: _busy ? null : _tryBiometric,
                        borderRadius: BorderRadius.circular(60),
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFE2EB),
                            shape: BoxShape.circle,
                          ),
                          child: _busy
                              ? const Padding(
                                  padding: EdgeInsets.all(36),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: _primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 64,
                                  color: _primary,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sentuh sensor / pindai wajah untuk masuk',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ink),
                    ),
                    if (_fails > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Percobaan gagal: $_fails dari $_maxFails',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB4234D)),
                      ),
                    ],
                  ] else ...[
                    if (_note != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEF1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _note!,
                          style: const TextStyle(
                            color: Color(0xFFB4234D),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pw,
                      enabled: !_busy,
                      obscureText: true,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitPassword(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy ? null : _submitPassword,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                  ],
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _err!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB4234D)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _busy ? null : _otherAccount,
                    child: const Text(
                      'Gunakan akun lain',
                      style: TextStyle(color: _primary),
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
