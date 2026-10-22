import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/auth/auth.dart';

/// Mengunci layar setelah 10 menit tanpa interaksi.
/// Sesi dapat dibuka kembali menggunakan biometrik atau password akun.
class SessionGuard extends StatefulWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  static const Duration _timeout = Duration(minutes: 10);

  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  Timer? _timer;
  DateTime? _lastActivity;
  DateTime? _lastPersistedActivity;
  int? _observedUserId;

  bool _locked = false;
  bool _checkingBiometrics = true;
  bool _hasBiometrics = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sessionRevision.addListener(_syncSession);
    _syncSession();
    _refreshBiometrics();
  }

  @override
  void dispose() {
    _timer?.cancel();
    sessionRevision.removeListener(_syncSession);
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _syncSession() {
    final currentUserId = myId;

    if (currentUserId == null) {
      _timer?.cancel();

      if (_observedUserId != null || _locked) {
        _observedUserId = null;
        _lastActivity = null;
        _lastPersistedActivity = null;

        if (mounted) {
          setState(() {
            _locked = false;
            _error = null;
            _passwordController.clear();
          });
        }
      }

      return;
    }

    if (_observedUserId != currentUserId) {
      _observedUserId = currentUserId;
      _lastActivity = sessionLastActivity ?? DateTime.now();
      _lastPersistedActivity = _lastActivity;
      _timer?.cancel();

      if (mounted) {
        setState(() {
          _locked = false;
          _error = null;
          _passwordController.clear();
        });
      }

      _scheduleTimeout();
    } else if (!_locked && _lastActivity == null) {
      _lastActivity = sessionLastActivity ?? DateTime.now();
      _lastPersistedActivity = _lastActivity;
      _scheduleTimeout();
    }
  }

  Future<void> _refreshBiometrics() async {
    var available = false;

    try {
      final enabled = await isBiometricLoginEnabled();
      if (enabled) {
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        final biometrics = canCheck
            ? await _localAuth.getAvailableBiometrics()
            : <BiometricType>[];

        available = supported && biometrics.isNotEmpty;
      }
    } catch (e) {
      debugPrint('[SESSION] Checking biometrics failed: $e');
      available = false;
    }

    if (!mounted) return;

    setState(() {
      _hasBiometrics = available;
      _checkingBiometrics = false;
    });
  }

  void _scheduleTimeout() {
    _timer?.cancel();

    if (myId == null || _locked || _lastActivity == null) {
      return;
    }

    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = _timeout - elapsed;

    if (remaining <= Duration.zero) {
      _lockScreen();
      return;
    }

    _timer = Timer(remaining, () {
      if (!mounted || myId == null || _locked) {
        return;
      }

      final last = _lastActivity;

      if (last != null && DateTime.now().difference(last) >= _timeout) {
        _lockScreen();
      } else {
        _scheduleTimeout();
      }
    });
  }

  void _recordActivity() {
    if (myId == null || _locked) {
      return;
    }

    _lastActivity = DateTime.now();
    sessionLastActivity = _lastActivity;
    _persistActivityIfNeeded();
    _scheduleTimeout();
  }

  void _persistActivityIfNeeded({bool force = false}) {
    final activity = _lastActivity;

    if (activity == null || myId == null) {
      return;
    }

    final previous = _lastPersistedActivity;

    if (!force &&
        previous != null &&
        activity.difference(previous) < const Duration(seconds: 15)) {
      return;
    }

    _lastPersistedActivity = activity;

    unawaited(
      store.write(
        key: 'last_activity',
        value: '${activity.millisecondsSinceEpoch}',
      ),
    );
  }

  void _lockScreen() {
    if (!mounted || myId == null || _locked) {
      return;
    }

    _timer?.cancel();
    _passwordController.clear();

    setState(() {
      _locked = true;
      _error = null;
    });
    // Preferensi dapat berubah saat aplikasi masih terbuka.
    unawaited(_refreshBiometrics());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (myId == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_locked) {
        return;
      }

      final last = _lastActivity;

      if (last != null && DateTime.now().difference(last) >= _timeout) {
        _lockScreen();
      } else {
        _scheduleTimeout();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Timer bisa ditangguhkan oleh OS; cek ulang saat aplikasi aktif.
      _timer?.cancel();
      _persistActivityIfNeeded(force: true);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy || !_hasBiometrics) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi identitas untuk membuka GlowClinic',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        await resetBiometricFailures();
        if (mounted) {
          _unlock();
        }
      } else {
        final failures = await recordBiometricFailure();
        if (mounted) {
          setState(() {
            if (failures >= 3) {
              _hasBiometrics = false;
              _error =
                  'Biometrik gagal 3 kali dan dinonaktifkan di Pengaturan. Buka dengan password.';
            } else {
              _error =
                  'Biometrik gagal atau dibatalkan ($failures/3). Coba lagi atau gunakan password.';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[SESSION] Biometric authentication failed: $e');
      final failures = await recordBiometricFailure();

      if (mounted) {
        setState(() {
          if (failures >= 3) {
            _hasBiometrics = false;
            _error =
                'Biometrik gagal 3 kali dan dinonaktifkan di Pengaturan. Buka dengan password.';
          } else {
            _error =
                'Biometrik tidak berhasil ($failures/3). Gunakan password atau coba lagi.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _unlockWithPassword() async {
    if (_busy || myId == null) {
      return;
    }

    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _error = 'Masukkan password akunmu.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rows = await qry(
        'SELECT salt, pass_hash FROM users WHERE id = ? LIMIT 1',
        [myId],
      );

      if (rows.isNotEmpty) {
        final salt = rows.first['salt']?.toString() ?? '';
        final expectedHash = rows.first['pass_hash']?.toString() ?? '';

        if (salt.isNotEmpty &&
            expectedHash.isNotEmpty &&
            hashPw(salt, password) == expectedHash) {
          if (mounted) {
            _unlock();
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _error = 'Password salah. Silakan coba lagi.';
        });
      }
    } catch (e) {
      debugPrint('[SESSION] Password verification failed: $e');

      if (mounted) {
        setState(() {
          _error = 'Gagal memverifikasi password. Coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _unlock() {
    if (!mounted) {
      return;
    }

    _timer?.cancel();
    _passwordController.clear();

    setState(() {
      _locked = false;
      _error = null;
      _lastActivity = DateTime.now();
      sessionLastActivity = _lastActivity;
      _lastPersistedActivity = null;
    });

    _persistActivityIfNeeded(force: true);
    _scheduleTimeout();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _recordActivity();
        }

        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _recordActivity(),
        onPointerMove: (_) => _recordActivity(),
        onPointerSignal: (_) => _recordActivity(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_locked)
              Positioned.fill(
                child: Material(
                  color: const Color(0xFFFFF8F6),
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3E4E8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_rounded,
                                  color: Color(0xFF641F35),
                                  size: 42,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'GlowClinic terkunci',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF641F35),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sesi dikunci setelah 10 menit tanpa aktivitas. '
                                'Verifikasi untuk melanjutkan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF9A7B84),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),
                              if (_checkingBiometrics)
                                const Center(
                                  child: CircularProgressIndicator(),
                                )
                              else if (_hasBiometrics) ...[
                                FilledButton.icon(
                                  onPressed:
                                      _busy ? null : _unlockWithBiometrics,
                                  icon: const Icon(Icons.fingerprint_rounded),
                                  label: const Text('Buka dengan biometrik'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF641F35),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('atau password'),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: true,
                                enabled: !_busy,
                                onSubmitted: (_) => _unlockWithPassword(),
                                decoration: InputDecoration(
                                  labelText: 'Password akun GlowClinic',
                                  prefixIcon:
                                      const Icon(Icons.password_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _busy ? null : _unlockWithPassword,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF641F35),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Buka dengan password'),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _busy ? null : () => logout(context),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Keluar dan login ulang'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF641F35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
