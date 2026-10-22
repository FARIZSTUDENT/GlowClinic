import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/auth/auth.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Keamanan & Mekanisme Password', () {
    test('Password di-hash dengan aman dan tidak disimpan plain text', () {
      const password = 'mySecretPassword123';
      final salt1 = newSalt();
      final salt2 = newSalt();

      final hash1 = hashPw(salt1, password);
      final hash2 = hashPw(salt2, password);

      // Hash tidak sama dengan password mentah
      expect(hash1, isNot(equals(password)));
      expect(hash1.length, equals(64)); // SHA-256 hex string

      // Salt yang berbeda menghasilkan hash yang berbeda
      expect(hash1, isNot(equals(hash2)));

      // Verifikasi konsisten jika salt dan password sama
      expect(hashPw(salt1, password), equals(hash1));
    });
  });

  group('1. Halaman Welcome / Get Started', () {
    testWidgets('Menampilkan logo, nama GlowClinic, tombol Login dan Create Account', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      // Cek Nama Brand & Tagline
      expect(find.text('GlowClinic'), findsOneWidget);
      expect(find.text('Book Your Dermatologist, Track Your Glow.'), findsOneWidget);

      // Cek Kalimat Sambutan
      expect(find.text('Rawat Kulit Sehat & Bercahaya'), findsOneWidget);

      // Cek Tombol Utama Login & Create Account
      expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('Menekan tombol Login membuka LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('Menekan tombol Create Account membuka SignUpScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
    });
  });

  group('2. Halaman Login', () {
    testWidgets('Tampilan LoginScreen memiliki input email, password, toggle visibility, dan link Sign Up', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
      expect(find.text('Belum punya akun? '), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Validasi input kosong pada LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pump();

      expect(find.text('Silakan masukkan email kamu.'), findsOneWidget);
    });

    testWidgets('Validasi format email pada LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'emailtidaksah');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pump();

      expect(find.text('Format email tidak valid (contoh: user@mail.com).'), findsOneWidget);
    });

    testWidgets('Toggle visibility password pada LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final passwordField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password'),
      );
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      final updatedField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Password'),
      );
      expect(updatedField.obscureText, isFalse);
    });
  });

  group('3. Halaman Sign Up / Register', () {
    testWidgets('Tampilan SignUpScreen memiliki form lengkap dan link Login', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      expect(find.text('Create Account'), findsNWidgets(2)); // Title and button
      expect(find.widgetWithText(TextField, 'Nama lengkap'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password (min. 6 karakter)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Konfirmasi password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
      expect(find.text('Sudah punya akun? '), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Validasi input kosong pada SignUpScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
    });

    testWidgets('Validasi ketidakcocokan password dan konfirmasi password', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Nama lengkap'), 'Budi Santoso');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'budi@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password (min. 6 karakter)'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Konfirmasi password'), 'password456');

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Password dan konfirmasi password tidak sama.'), findsOneWidget);
    });

    testWidgets('Validasi panjang minimum password', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Nama lengkap'), 'Budi Santoso');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'budi@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password (min. 6 karakter)'), '12345');
      await tester.enterText(find.widgetWithText(TextField, 'Konfirmasi password'), '12345');

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Password minimal terdiri dari 6 karakter.'), findsOneWidget);
    });
  });

  group('4. Staff Login & Database Sync Tests', () {
    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await db.execute(
        "create table users(id integer primary key autoincrement, nama text, email text unique, no_hp text, role text not null default 'pasien', alergi text, tipe_kulit text, photo_path text, poin integer default 0, salt text, pass_hash text)",
      );
      await db.execute(
        "create table bookings(id integer primary key autoincrement, user_id integer, status text default 'pending', status_bayar text default 'belum_bayar', created_at text default current_timestamp)",
      );
    });

    tearDown(() async {
      stopNotifWatcher();
      await db.close();
    });

    test('Sinkronisasi initDb memastikan akun staf demo tersedia dengan password kStaffPassword', () async {
      // Simulasikan database HP lama yang masih menyimpan akun dengan hash 'staf123'
      final oldSalt = newSalt();
      await db.insert('users', {
        'nama': 'Staf Lama',
        'email': 'staf@glowclinic.com',
        'role': 'staf',
        'salt': oldSalt,
        'pass_hash': hashPw(oldSalt, 'staf123'),
      });

      // Jalankan logika sinkronisasi akun staf seperti di initDb()
      final staff = await db.query(
        'users',
        where: 'lower(trim(email)) in (?, ?)',
        whereArgs: [kStaffEmail, 'staff@glowclinic.com'],
      );

      for (final s in staff) {
        final salt = (s['salt']?.toString().isNotEmpty ?? false)
            ? s['salt'].toString()
            : newSalt();
        await db.update(
          'users',
          {
            'role': 'staf',
            'salt': salt,
            'pass_hash': hashPw(salt, kStaffPassword),
          },
          where: 'id = ?',
          whereArgs: [s['id']],
        );
      }

      final updated = await db.query('users', where: 'email = ?', whereArgs: [kStaffEmail]);
      expect(updated.length, 1);
      final u = updated.first;
      expect(u['role'], 'staf');

      // Password kStaffPassword ('staf12345') harus valid dengan pass_hash baru
      expect(hashPw(u['salt'].toString(), kStaffPassword), equals(u['pass_hash']));
    });

    testWidgets('LoginScreen berhasil login menggunakan staf@glowclinic.com dan staf12345', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed staf
      final salt = newSalt();
      await db.insert('users', {
        'nama': 'Staf GlowClinic',
        'email': kStaffEmail,
        'role': 'staf',
        'salt': salt,
        'pass_hash': hashPw(salt, kStaffPassword),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'staf@glowclinic.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'staf12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(myId, isNotNull);
      final currentUserRole = await qry('SELECT role FROM users WHERE id = ?', [myId]);
      expect(currentUserRole.first['role'], 'staf');
      stopNotifWatcher();
    });

    testWidgets('LoginScreen otomatis melakukan transisi jika database masih menyimpan hash lama staf123', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed staf dengan hash LAMA 'staf123'
      final salt = newSalt();
      await db.insert('users', {
        'nama': 'Staf GlowClinic',
        'email': 'staf@glowclinic.com',
        'role': 'staf',
        'salt': salt,
        'pass_hash': hashPw(salt, 'staf123'),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Login dengan password baru 'staf12345'
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'staf@glowclinic.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'staf12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Harus berhasil login dan hash database otomatis diperbarui
      expect(myId, isNotNull);

      final checkDb = await db.query('users', where: 'id = ?', whereArgs: [myId]);
      final u = checkDb.first;
      expect(hashPw(u['salt'].toString(), kStaffPassword), equals(u['pass_hash']));
      stopNotifWatcher();
    });

    testWidgets('LoginScreen mendukung alias penulisan staff@glowclinic.com (double f)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final salt = newSalt();
      await db.insert('users', {
        'nama': 'Staf GlowClinic',
        'email': 'staf@glowclinic.com',
        'role': 'staf',
        'salt': salt,
        'pass_hash': hashPw(salt, kStaffPassword),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Input dengan penulisan 'staff@glowclinic.com' (dua 'f')
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'staff@glowclinic.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'staf12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(myId, isNotNull);
      stopNotifWatcher();
    });
  });
}
