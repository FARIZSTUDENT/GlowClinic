import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:glowclinic/features/bot/glowbot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GlowBotService Unit Tests', () {
    test('1. Menangani API key yang belum tersedia (tanpa request jaringan)', () async {
      final answer = await GlowBotService.generateReply(
        apiKey: '',
        model: 'gemini-1.5-flash',
        systemPrompt: 'System prompt',
        history: [],
        userMessage: 'hai',
      );

      expect(answer, contains('GlowBot belum dikonfigurasi'));
      expect(answer, contains('--dart-define=GEMINI_KEY'));
    });

    test('2. Berhasil mengirim pesan ke Gemini dan membaca jawaban AI (200 OK)', () async {
      String? capturedUrl;
      Map<String, String>? capturedHeaders;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedUrl = request.url.toString();
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        final mockResponse = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text':
                        'Halo! Senang bisa menyapa kamu di GlowClinic. Ada yang bisa GlowBot bantu hari ini seputar perawatan kulitmu? ✨'
                  }
                ],
                'role': 'model'
              },
              'finishReason': 'STOP',
              'index': 0,
            }
          ]
        };

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'AIzaSyDemoValidKey123',
        model: 'gemini-1.5-flash',
        systemPrompt: 'Instruksi sistem GlowClinic',
        history: [],
        userMessage: 'hai',
        client: mockClient,
      );

      expect(
        answer,
        equals(
          'Halo! Senang bisa menyapa kamu di GlowClinic. Ada yang bisa GlowBot bantu hari ini seputar perawatan kulitmu? ✨',
        ),
      );

      // Verifikasi struktur request yang dikirim ke Gemini
      expect(capturedUrl, contains('models/gemini-1.5-flash:generateContent'));
      expect(capturedHeaders?['x-goog-api-key'], equals('AIzaSyDemoValidKey123'));
      expect(capturedHeaders?['content-type'], contains('application/json'));

      // Verifikasi body request
      expect(capturedBody?['system_instruction']?['parts']?[0]?['text'], equals('Instruksi sistem GlowClinic'));
      expect(capturedBody?['contents']?[0]?['role'], equals('user'));
      expect(capturedBody?['contents']?[0]?['parts']?[0]?['text'], equals('hai'));
      expect(capturedBody?['generationConfig']?['maxOutputTokens'], equals(1024));
      expect(capturedBody?['generationConfig']?['thinkingConfig'], isNull); // Tidak boleh ada thinkingConfig
    });

    test('3. Menangani pertanyaan tentang treatment GlowClinic', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text':
                        'Di GlowClinic kami memiliki Facial Medis (Rp 350.000) dan Laser Rejuvenation (Rp 1.200.000). Untuk konsultasi awal, kamu bisa mengambil Konsultasi Dokter (Rp 150.000).'
                  }
                ],
                'role': 'model'
              }
            }
          ]
        };

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'AIzaSyTestKey',
        model: 'gemini-1.5-flash',
        systemPrompt: 'GlowClinic Treatments',
        history: [],
        userMessage: 'Apa saja treatment yang tersedia di GlowClinic?',
        client: mockClient,
      );

      expect(answer, contains('Facial Medis'));
      expect(answer, contains('Laser Rejuvenation'));
    });

    test('4. Menangani multi-turn conversation (pengiriman pesan berurutan)', () async {
      Map<String, dynamic>? lastCapturedBody;

      final mockClient = MockClient((request) async {
        lastCapturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        final mockResponse = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text':
                        'Sebelum facial, bersihkan wajah dari riasan tebal dan hindari eksfoliasi keras 2 hari sebelumnya ya.'
                  }
                ],
                'role': 'model'
              }
            }
          ]
        };

        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final history = [
        {'role': 'user', 'text': 'hai'},
        {'role': 'model', 'text': 'Halo! Ada yang bisa dibantu?'},
      ];

      final answer = await GlowBotService.generateReply(
        apiKey: 'AIzaSyTestKey',
        model: 'gemini-1.5-flash',
        systemPrompt: 'GlowClinic instructions',
        history: history,
        userMessage: 'Apa persiapan sebelum facial?',
        client: mockClient,
      );

      expect(answer, contains('Sebelum facial'));

      // Verifikasi urutan contents: user -> model -> user
      final contents = lastCapturedBody?['contents'] as List;
      expect(contents.length, equals(3));
      expect(contents[0]['role'], equals('user'));
      expect(contents[0]['parts'][0]['text'], equals('hai'));
      expect(contents[1]['role'], equals('model'));
      expect(contents[1]['parts'][0]['text'], equals('Halo! Ada yang bisa dibantu?'));
      expect(contents[2]['role'], equals('user'));
      expect(contents[2]['parts'][0]['text'], equals('Apa persiapan sebelum facial?'));
    });

    test('5. Menangani API key tidak valid (HTTP 401 / 403)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 401,
              'message': 'API_KEY_INVALID: API key not valid.',
              'status': 'UNAUTHENTICATED'
            }
          }),
          401,
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'InvalidKey',
        model: 'gemini-1.5-flash',
        systemPrompt: 'prompt',
        history: [],
        userMessage: 'hai',
        client: mockClient,
      );

      expect(answer, contains('API key Gemini tidak valid'));
      expect(answer, isNot(contains('InvalidKey'))); // Key tidak boleh dibocorkan!
    });

    test('6. Menangani batas kuota tercapai (HTTP 429)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 429,
              'message': 'Resource has been exhausted (e.g. check quota).',
              'status': 'RESOURCE_EXHAUSTED'
            }
          }),
          429,
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'Key',
        model: 'gemini-1.5-flash',
        systemPrompt: 'prompt',
        history: [],
        userMessage: 'hai',
        client: mockClient,
      );

      expect(answer, contains('Batas kuota penggunaan Gemini API tercapai'));
    });

    test('7. Menangani server sibuk (HTTP 503)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 503,
              'message': 'The model is overloaded. Please try again later.',
              'status': 'UNAVAILABLE'
            }
          }),
          503,
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'Key',
        model: 'gemini-1.5-flash',
        systemPrompt: 'prompt',
        history: [],
        userMessage: 'hai',
        client: mockClient,
      );

      expect(answer, contains('Server Gemini sedang sibuk'));
    });

    test('8. Menangani kegagalan koneksi jaringan / ClientException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Failed to connect to host');
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'Key',
        model: 'gemini-1.5-flash',
        systemPrompt: 'prompt',
        history: [],
        userMessage: 'hai',
        client: mockClient,
      );

      expect(answer, contains('Gagal terhubung ke GlowBot'));
    });

    test('9. Menangani respons yang diblokir oleh Safety Setting', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'SAFETY',
                'index': 0,
              }
            ]
          }),
          200,
        );
      });

      final answer = await GlowBotService.generateReply(
        apiKey: 'Key',
        model: 'gemini-1.5-flash',
        systemPrompt: 'prompt',
        history: [],
        userMessage: 'pesan berbahaya',
        client: mockClient,
      );

      expect(answer, contains('kebijakan keamanan konten AI'));
    });

    test('10. buildSystemPrompt menghasilkan konteks lengkap data klinik dan disclaimer medis', () {
      final prompt = GlowBotService.buildSystemPrompt(
        treatments: [
          {
            'nama': 'Facial Medis',
            'kategori': 'Facial',
            'durasi_menit': 60,
            'harga_idr': 350000,
            'deskripsi': 'Pembersihan mendalam kulit wajah',
          }
        ],
        branches: [
          {
            'nama': 'GlowClinic Pusat',
            'alamat': 'Jl. Malioboro',
            'jam_buka': '09:00 - 18:00',
          }
        ],
        doctors: [
          {
            'nama': 'dr. Rina Aulia, Sp.KK',
            'spesialisasi': 'Dermatologi',
            'jadwal_praktik': 'Senin - Rabu',
            'deskripsi': 'Dokter spesialis kulit',
          }
        ],
      );

      expect(prompt, contains('GlowBot'));
      expect(prompt, contains('Facial Medis'));
      expect(prompt, contains('Rp 350000'));
      expect(prompt, contains('GlowClinic Pusat'));
      expect(prompt, contains('dr. Rina Aulia, Sp.KK'));
      expect(prompt, contains('BUKAN dokter'));
      expect(prompt, contains('tab menu "Booking"'));
      expect(prompt, contains('PRE-TREATMENT'));
      expect(prompt, contains('AFTERCARE'));
    });
  });

  group('ChatScreen Widget Tests', () {
    testWidgets('Tampilan halaman ChatScreen dan interaksi kirim pesan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifikasi komponen utama GlowBot ada di layar
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Kirim pesan'), findsOneWidget);
      expect(find.textContaining('GlowBot bukan alat diagnosis medis'), findsOneWidget);

      // Verifikasi quick chips muncul di awal percakapan
      expect(find.textContaining('Layanan & Harga'), findsOneWidget);
      expect(find.textContaining('Cabang & Jam Buka'), findsOneWidget);
      expect(find.textContaining('Cara Booking'), findsOneWidget);

      // Pengguna mengetik "hai"
      await tester.enterText(find.byType(TextField), 'hai');
      await tester.tap(find.byTooltip('Kirim pesan'));
      await tester.pump();

      // Bubble pesan user muncul
      expect(find.text('hai'), findsOneWidget);

      // Bot membalas (karena di unit test tanpa --dart-define, muncul instruksi konfigurasi)
      await tester.pumpAndSettle();
      expect(find.textContaining('GlowBot belum dikonfigurasi'), findsOneWidget);

      // Tombol dan textfield kembali aktif setelah selesai
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
    });
  });
}
