import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/home/patient_home.dart';
import 'package:glowclinic/features/home/staff_home.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/features/notif/notif.dart';

// ============================================================
// GLOWCLINIC BRAND CONSTANTS & PALETTE
// Luxury skincare theme - pink, maroon, white, elegant aesthetics
// ============================================================

const Color glowMaroon = Color(0xFF641F35);
const Color glowDark = Color(0xFF481526);
const Color glowBackground = Color(0xFFFFF8F6);
const Color glowPink = Color(0xFFF3E4E8);
const Color glowText = Color(0xFF49343B);
const Color glowMuted = Color(0xFF9A7B84);
const Color glowBorder = Color(0xFFEAD8DE);

// ============================================================
// BRAND HEADER COMPONENT
// ============================================================

class GlowClinicBrand extends StatelessWidget {
  final bool compact;

  const GlowClinicBrand({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double logoSize = compact ? 84.0 : 124.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize + 16,
          height: logoSize + 16,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowMaroon.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: glowPink,
              width: 1.5,
            ),
          ),
          child: Image.asset(
            'assets/images/glowclinic_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.spa_rounded,
                color: glowMaroon,
                size: 44,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'GlowClinic',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: compact ? 26 : 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: glowMaroon,
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Book Your Dermatologist, Track Your Glow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w500,
              color: glowMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PENGELOLAAN SESI LOGIN
// ============================================================

Future<void> startSession(int id) async {
  myId = id;
  sessionLastActivity = DateTime.now();
  sessionRevision.value++;

  await store.write(key: 'uid', value: '$id');
  await store.write(
    key: 'exp',
    value:
        '${DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch}',
  );
  await store.write(key: 'tok', value: newSalt());
  await store.write(
    key: 'last_activity',
    value: '${sessionLastActivity!.millisecondsSinceEpoch}',
  );
  await store.write(key: 'last_uid', value: '$id');
}

Future<bool> loadSession() async {
  try {
    final u = await store.read(key: 'uid');
    final e = await store.read(key: 'exp');
    final lastActivityRaw = await store.read(key: 'last_activity');

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
    final lastActivityMs = int.tryParse(lastActivityRaw ?? '');
    sessionLastActivity = lastActivityMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(lastActivityMs);
    if (lastActivityMs == null) {
      await store.write(
        key: 'last_activity',
        value: '${sessionLastActivity!.millisecondsSinceEpoch}',
      );
    }
    sessionRevision.value++;
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
  sessionLastActivity = null;
  sessionRevision.value++;

  for (final key in ['uid', 'exp', 'tok', 'last_activity']) {
    await store.delete(key: key);
  }
}

Future<void> forgetAccount() async {
  try {
    await clearSession();
    await store.delete(key: 'last_uid');
  } catch (_) {
    myId = null;
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
        builder: (_) => const WelcomeScreen(),
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
      builder: (_) => const WelcomeScreen(),
    ),
    (_) => false,
  );
}

// ============================================================
// GATE (ROOT ENTRY WIDGET)
// Memeriksa validitas sesi:
// - Jika sesi masih valid -> arahkan langsung ke halaman utama
// - Jika belum login / sesi habis -> tampilkan WelcomeScreen
// ============================================================

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthSession();
  }

  Future<void> _checkAuthSession() async {
    try {
      final isValid = await loadSession();

      if (!mounted) return;

      if (isValid && myId != null) {
        final rows = await qry('select role from users where id=?', [myId]);
        if (!mounted) return;

        if (rows.isNotEmpty) {
          await goHome(context);
          return;
        } else {
          await clearSession();
        }
      }
    } catch (_) {
      try {
        await clearSession();
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _checking = false;
    });
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

    return const WelcomeScreen();
  }
}

// ============================================================
// 1. HALAMAN WELCOME / GET STARTED
// Tampilan awal saat pengguna belum login
// ============================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: glowBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),

                  // LOGO & NAMA APLIKASI
                  const GlowClinicBrand(compact: false),

                  const SizedBox(height: 32),

                  // KARTU SAMBUTAN KLINIK KECANTIKAN
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: glowPink),
                      boxShadow: [
                        BoxShadow(
                          color: glowMaroon.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: glowPink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: glowMaroon,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Kecantikan & Kulit',
                                style: TextStyle(
                                  color: glowMaroon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Rawat Kulit Sehat & Bercahaya',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: glowText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Konsultasikan kondisi kulitmu dengan dokter spesialis berpengalaman. Booking jadwal perawatan dengan mudah dan praktis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: glowMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // TOMBOL UTAMA "LOGIN"
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: glowMaroon,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // TOMBOL "SIGN UP" / "CREATE ACCOUNT"
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: glowMaroon,
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: glowMaroon,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Akun staf disediakan oleh administrator klinik.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: glowMuted,
                      fontSize: 11,
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
// 2. HALAMAN LOGIN
// ============================================================

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final bool justRegistered;

  const LoginScreen({
    super.key,
    this.initialEmail,
    this.justRegistered = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailNotFound = false;
  bool _biometricLoginStarted = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricLogin();
    });
  }

  Future<void> _tryBiometricLogin() async {
    if (_biometricLoginStarted || !mounted) return;
    _biometricLoginStarted = true;

    try {
      if (!await isBiometricLoginEnabled()) return;

      final savedUserId = await biometricLoginUserId();
      if (savedUserId == null) return;

      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = canCheck
          ? await _localAuth.getAvailableBiometrics()
          : <BiometricType>[];

      if (!supported || available.isEmpty || !mounted) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isEmailNotFound = false;
      });

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi identitas untuk masuk ke GlowClinic',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        await resetBiometricFailures();
        final rows = await qry(
          'SELECT id FROM users WHERE id = ? LIMIT 1',
          [savedUserId],
        );

        if (rows.isEmpty) {
          await setBiometricLoginEnabled(false);
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Akun biometrik tidak ditemukan. Silakan login dengan password.';
          });
          return;
        }

        final userId = int.tryParse(rows.first['id'].toString());
        if (userId == null) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Akun tidak valid. Silakan login dengan password.';
          });
          return;
        }

        await startSession(userId);
        if (!mounted) return;
        await goHome(context);
        return;
      }

      final failures = await recordBiometricFailure();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = failures >= 3
            ? 'Biometrik gagal 3 kali dan dinonaktifkan. Silakan login dengan password.'
            : 'Verifikasi biometrik gagal atau dibatalkan. Silakan gunakan password.';
      });
    } catch (e) {
      debugPrint('[AUTH] Automatic biometric login failed: $e');
      if (!mounted) return;

      final failures = await recordBiometricFailure();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = failures >= 3
            ? 'Biometrik gagal 3 kali dan dinonaktifkan. Silakan login dengan password.'
            : 'Biometrik tidak berhasil. Silakan login dengan password.';
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan email kamu.';
        _isEmailNotFound = false;
      });
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Format email tidak valid (contoh: user@mail.com).';
        _isEmailNotFound = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan masukkan password.';
        _isEmailNotFound = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isEmailNotFound = false;
    });

    try {
      debugPrint('[AUTH] Memproses login untuk email: $email');

      // Dukungan alias email staf demo: 'staf@glowclinic.com' maupun 'staff@glowclinic.com'
      final isStaffInput = (email == kStaffEmail || email == 'staff@glowclinic.com');
      final queryEmail = isStaffInput ? kStaffEmail : email;

      var rows = await qry(
        'select * from users where lower(trim(email)) = ?',
        [queryEmail],
      );

      // Jika input staf dan belum ditemukan dengan kStaffEmail, coba cari dengan 'staff@glowclinic.com'
      if (rows.isEmpty && isStaffInput) {
        rows = await qry(
          'select * from users where lower(trim(email)) in (?, ?)',
          [kStaffEmail, 'staff@glowclinic.com'],
        );
      }

      if (!mounted) return;

      if (rows.isEmpty) {
        debugPrint('[AUTH] Akun dengan email "$email" tidak ditemukan di database perangkat.');
        setState(() {
          _isLoading = false;
          _isEmailNotFound = true;
          _errorMessage =
              'Akun dengan email ini belum terdaftar di GlowClinic.';
        });
        return;
      }

      final user = rows.first;
      final salt = user['salt']?.toString() ?? '';
      final passHash = user['pass_hash']?.toString() ?? '';
      final userRole = user['role']?.toString().toLowerCase().trim() ?? 'pasien';

      debugPrint('[AUTH] Akun ditemukan: id=${user['id']}, role=$userRole');

      // Validasi password pengguna
      bool isValidPassword = salt.isNotEmpty &&
          passHash.isNotEmpty &&
          hashPw(salt, password) == passHash;

      // Fallback transisi khusus akun staf demo:
      // Membantu perangkat fisik yang databasenya dibuat saat password masih 'staf123',
      // atau jika kStaffPassword digunakan sebelum sinkronisasi initDb.
      if (!isValidPassword && isStaffInput && (password == kStaffPassword || password == 'staf123')) {
        debugPrint('[AUTH] Sinkronisasi hash password akun staf demo di database perangkat.');
        isValidPassword = true;
        final newSaltVal = newSalt();
        await db.update(
          'users',
          {
            'role': 'staf',
            'salt': newSaltVal,
            'pass_hash': hashPw(newSaltVal, kStaffPassword),
          },
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }

      if (!isValidPassword) {
        debugPrint('[AUTH] Password tidak cocok untuk email "$email".');
        setState(() {
          _isLoading = false;
          _isEmailNotFound = false;
          _errorMessage =
              'Password salah. Silakan periksa kembali password kamu.';
        });
        return;
      }

      final userId = user['id'] as int;
      debugPrint('[AUTH] Login berhasil! userId=$userId, role=$userRole. Mengarahkan ke halaman utama...');

      if (await isBiometricLoginEnabled()) {
        await store.write(key: 'biometric_uid', value: '$userId');
        await resetBiometricFailures();
      }

      await startSession(userId);

      if (!mounted) return;
      await goHome(context);
    } catch (e) {
      debugPrint('[AUTH] Error saat memproses login: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEmailNotFound = false;
        _errorMessage = 'Gagal memproses login. Silakan coba lagi.';
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: glowMuted,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: glowMaroon,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glowBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glowBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: glowMaroon,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFB4234D),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: glowBackground,
      appBar: AppBar(
        backgroundColor: glowBackground,
        foregroundColor: glowText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlowClinicBrand(compact: true),
                  const SizedBox(height: 24),

                  // KARTU LOGIN
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: glowPink),
                      boxShadow: [
                        BoxShadow(
                          color: glowMaroon.withValues(alpha: 0.06),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: glowText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masuk menggunakan email dan password akunmu.',
                          style: TextStyle(
                            color: glowMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // INPUT EMAIL
                        TextField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // INPUT PASSWORD
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) _login();
                          },
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: glowMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        // PESAN ERROR
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF9D2D9),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFB4234D),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFB4234D),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isEmailNotFound) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SignUpScreen(
                                            initialEmail: _emailController.text
                                                .trim()
                                                .toLowerCase(),
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFB4234D),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 15,
                                            color: Color(0xFFB4234D),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Daftar akun sekarang (Sign Up)',
                                            style: TextStyle(
                                              color: Color(0xFFB4234D),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // TOMBOL LOGIN
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: glowMaroon,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TEKS BELUM PUNYA AKUN? SIGN UP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Belum punya akun? ',
                        style: TextStyle(
                          color: glowMuted,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: glowMaroon,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
// 3. HALAMAN SIGN UP / REGISTER
// ============================================================

class SignUpScreen extends StatefulWidget {
  final String? initialEmail;

  const SignUpScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailAlreadyRegistered = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Nama lengkap wajib diisi.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email wajib diisi.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Format email tidak valid (contoh: nama@domain.com).';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Password wajib diisi.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password minimal terdiri dari 6 karakter.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Konfirmasi password wajib diisi.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Password dan konfirmasi password tidak sama.';
        _isEmailAlreadyRegistered = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isEmailAlreadyRegistered = false;
    });

    try {
      final existing = await qry(
        'select id from users where lower(trim(email)) = ?',
        [email],
      );

      if (!mounted) return;

      if (existing.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _isEmailAlreadyRegistered = true;
          _errorMessage =
              'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
        });
        return;
      }

      final salt = newSalt();
      final passHash = hashPw(salt, password);

      await db.insert('users', {
        'nama': name,
        'email': email,
        'role': 'pasien',
        'salt': salt,
        'pass_hash': passHash,
        'poin': 0,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Akun berhasil dibuat! Silakan masuk dengan akun baru kamu.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            initialEmail: email,
            justRegistered: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isEmailAlreadyRegistered = false;
        _errorMessage = 'Gagal membuat akun: $e';
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: glowMuted,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: glowMaroon,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glowBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glowBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: glowMaroon,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFB4234D),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: glowBackground,
      appBar: AppBar(
        backgroundColor: glowBackground,
        foregroundColor: glowText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlowClinicBrand(compact: true),
                  const SizedBox(height: 24),

                  // KARTU SIGN UP
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: glowPink),
                      boxShadow: [
                        BoxShadow(
                          color: glowMaroon.withValues(alpha: 0.06),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: glowText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Daftar akun baru untuk mulai perawatan kecantikanmu.',
                          style: TextStyle(
                            color: glowMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // INPUT NAMA LENGKAP
                        TextField(
                          controller: _nameController,
                          enabled: !_isLoading,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Nama lengkap',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // INPUT EMAIL
                        TextField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // INPUT PASSWORD
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Password (min. 6 karakter)',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: glowMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // INPUT KONFIRMASI PASSWORD
                        TextField(
                          controller: _confirmPasswordController,
                          enabled: !_isLoading,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) _signUp();
                          },
                          decoration: _inputDecoration(
                            label: 'Konfirmasi password',
                            icon: Icons.lock_reset_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: glowMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),

                        // PESAN ERROR
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF9D2D9),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFB4234D),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFB4234D),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isEmailAlreadyRegistered) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LoginScreen(
                                            initialEmail: _emailController.text
                                                .trim()
                                                .toLowerCase(),
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFB4234D),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.login_rounded,
                                            size: 15,
                                            color: Color(0xFFB4234D),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Masuk ke Akun (Login)',
                                            style: TextStyle(
                                              color: Color(0xFFB4234D),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // TOMBOL CREATE ACCOUNT
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: glowMaroon,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _signUp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TEKS SUDAH PUNYA AKUN? LOGIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun? ',
                        style: TextStyle(
                          color: glowMuted,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: glowMaroon,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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