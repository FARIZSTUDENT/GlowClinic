import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/home/patient_home.dart';
import 'package:glowclinic/features/home/staff_home.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/features/notif/notif.dart';

// ============================================================
// GLOWCLINIC BRAND
// Luxury skincare - maroon, white, minimal feminine line art
// ============================================================

const Color glowMaroon = Color(0xFF87364B);
const Color glowBackground = Color(0xFFFFFDFD);
const Color glowPink = Color(0xFFF8EDF0);
const Color glowText = Color(0xFF513B45);

class GlowClinicBrand extends StatelessWidget {
  final bool compact;

  const GlowClinicBrand({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ukuran logo disesuaikan dengan tampilan layar.
    final double logoSize = compact ? 110.0 : 150.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/glowclinic_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return SizedBox(
              width: logoSize,
              height: logoSize,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: glowMaroon,
                size: 40,
              ),
            );
          },
        ),

        const SizedBox(height: 4),

        Text(
          'GlowClinic',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: compact ? 30 : 36,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.0,
            color: glowMaroon,
          ),
        ),

        const SizedBox(height: 6),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Book Your Dermatologist, Track Your Glow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.25,
              height: 1.4,
              color: glowMaroon,
            ),
          ),
        ),
      ],
    );
  }
}
// ============================================================
// MENGELOLA SESI LOGIN
// ============================================================

Future<void> startSession(int id) async {
  myId = id;

  await store.write(
    key: 'uid',
    value: '$id',
  );

  await store.write(
    key: 'exp',
    value:
        '${DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch}',
  );

  await store.write(
    key: 'tok',
    value: newSalt(),
  );

  await store.write(
    key: 'last_uid',
    value: '$id',
  );
}

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
  } catch (_) {
    try {
      await clearSession();
    } catch (_) {}

    myId = null;
    return false;
  }
}

Future<void> clearSession() async {
  myId = null;

  for (final key in ['uid', 'exp', 'tok']) {
    await store.delete(key: key);
  }
}

Future<void> goHome(BuildContext context) async {
  final result = await qry(
    'select role from users where id=?',
    [myId],
  );

  if (!context.mounted) return;

  if (result.isEmpty) {
    try {
      await clearSession();
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );

    return;
  }

  final role = '${result.first['role']}'.trim().toLowerCase();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ['staf', 'staff', 'admin'].contains(role)
              ? const StaffHome()
              : const PatientHome(),
    ),
    (_) => false,
  );
}

Future<void> forgetAccount() async {
  try {
    await clearSession();
    await store.delete(key: 'last_uid');
  } catch (_) {
    myId = null;
  }
}

Future<void> logout(BuildContext context) async {
  stopNotifWatcher();

  try {
    await cancelPromos();
  } catch (_) {}

  try {
    await clearSession();
  } catch (_) {
    myId = null;
  }

  if (!context.mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => const Gate(),
    ),
    (_) => false,
  );
}

// ============================================================
// GATE BIOMETRIK
// ============================================================

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _G();
}

class _G extends State<Gate> {
  static const int _maxFails = 3;

  final LocalAuthentication _auth = LocalAuthentication();
  final TextEditingController _password = TextEditingController();

  int? _uid;
  int _fails = 0;

  String _name = '';
  String? _note;
  String? _error;

  bool _checking = true;
  bool _busy = false;
  bool _askPassword = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _openLogin() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  Future<void> _start() async {
    int? id;

    try {
      final value = await store.read(key: 'uid') ??
          await store.read(key: 'last_uid');

      id = int.tryParse(value ?? '');
    } catch (_) {
      id = null;
    }

    if (id == null) {
      _openLogin();
      return;
    }

    final rows = await qry(
      'select id, nama from users where id=?',
      [id],
    );

    if (!mounted) return;

    if (rows.isEmpty) {
      await forgetAccount();
      _openLogin();
      return;
    }

    bool available = false;

    try {
      available = await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
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
        _note =
            'Biometrik belum tersedia atau belum terdaftar. '
            'Silakan masuk dengan password.';
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
      _error = null;
    });

    bool authenticated = false;

    try {
      authenticated = await _auth.authenticate(
        localizedReason: 'Verifikasi untuk masuk ke GlowClinic',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!authenticated) _fails++;
    } on PlatformException catch (e) {
      const fatalErrors = [
        'LockedOut',
        'PermanentlyLockedOut',
        'NotAvailable',
        'NotEnrolled',
        'PasscodeNotSet',
      ];

      _fails = fatalErrors.contains(e.code)
          ? _maxFails
          : _fails + 1;
    } catch (_) {
      _fails++;
    }

    if (!mounted) return;

    if (authenticated) {
      await _enter();
      return;
    }

    setState(() {
      _busy = false;

      if (_fails >= _maxFails) {
        _askPassword = true;
        _note =
            'Biometrik gagal $_maxFails kali. '
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
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = 'Gagal masuk. Silakan coba lagi.';
      });
    }
  }

  Future<void> _submitPassword() async {
    if (_busy || _uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rows = await qry(
        'select * from users where id=?',
        [_uid],
      );

      final valid = rows.isNotEmpty &&
          rows.first['salt'] != null &&
          rows.first['pass_hash'] != null &&
          hashPw(
                '${rows.first['salt']}',
                _password.text,
              ) ==
              '${rows.first['pass_hash']}';

      if (!valid) {
        if (!mounted) return;

        setState(() {
          _busy = false;
          _error = 'Password salah.';
        });

        return;
      }

      await _enter();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _error = 'Gagal memeriksa password. Coba lagi.';
      });
    }
  }

  Future<void> _otherAccount() async {
    await forgetAccount();
    _openLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: glowBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: glowMaroon,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: glowBackground,
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
                  const GlowClinicBrand(compact: true),
                  const SizedBox(height: 12),

                  Text(
                    _name.isEmpty
                        ? 'Selamat datang kembali'
                        : 'Halo, $_name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF927783),
                    ),
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
                            color: glowPink,
                            shape: BoxShape.circle,
                          ),
                          child: _busy
                              ? const Padding(
                                  padding: EdgeInsets.all(36),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: glowMaroon,
                                  ),
                                )
                              : const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 64,
                                  color: glowMaroon,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Sentuh sensor atau pindai wajah untuk masuk',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: glowText),
                    ),

                    if (_fails > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Percobaan gagal: $_fails dari $_maxFails',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB4234D),
                        ),
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
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitPassword(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: glowMaroon,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: glowMaroon,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: glowMaroon,
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

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB4234D),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _busy ? null : _otherAccount,
                    child: const Text(
                      'Gunakan akun lain',
                      style: TextStyle(color: glowMaroon),
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

// ============================================================
// LOGIN DAN REGISTRASI
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LS();
}

class _LS extends State<LoginScreen> {
  final TextEditingController em = TextEditingController();
  final TextEditingController pw = TextEditingController();
  final TextEditingController nm = TextEditingController();

  int step = 0;
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
      setState(() {
        err = 'Email tidak valid.';
      });
      return;
    }

    setState(() {
      busy = true;
      err = null;
    });

    try {
      final rows = await qry(
        'select 1 from users where lower(trim(email))=?',
        [email],
      );

      if (!mounted) return;

      setState(() {
        step = rows.isNotEmpty ? 1 : 2;
        err = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        err = 'Tidak dapat memeriksa akun. Pastikan database siap.';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
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
        final rows = await qry(
          'select * from users where lower(trim(email))=?',
          [email],
        );

        if (rows.isEmpty ||
            rows.first['salt'] == null ||
            rows.first['pass_hash'] == null ||
            hashPw(
                  '${rows.first['salt']}',
                  pw.text,
                ) !=
                '${rows.first['pass_hash']}') {
          throw Exception('Email atau password salah.');
        }

        id = rows.first['id'] as int;
      } else {
        if (nm.text.trim().isEmpty) {
          throw Exception('Nama wajib diisi.');
        }

        if (pw.text.length < 6) {
          throw Exception('Password minimal 6 karakter.');
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
      if (!mounted) return;

      setState(() {
        err = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: glowMaroon,
      ),
      filled: true,
      fillColor: const Color(0xFFFFFAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEAD8DE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: glowMaroon,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: glowBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlowClinicBrand(),
                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFEAD8DE),
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
                            color: glowText,
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
                          autofillHints: const [
                            AutofillHints.email,
                          ],
                          decoration: _decoration(
                            'Email',
                            Icons.mail_outline_rounded,
                          ),
                        ),

                        if (step == 2) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: nm,
                            enabled: !busy,
                            textCapitalization:
                                TextCapitalization.words,
                            autofillHints: const [
                              AutofillHints.name,
                            ],
                            decoration: _decoration(
                              'Nama lengkap',
                              Icons.person_outline_rounded,
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
                            decoration: _decoration(
                              step == 2
                                  ? 'Buat password (min. 6 karakter)'
                                  : 'Password',
                              Icons.lock_outline_rounded,
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
                              backgroundColor: glowMaroon,
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
                              style: TextStyle(
                                color: glowMaroon,
                              ),
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