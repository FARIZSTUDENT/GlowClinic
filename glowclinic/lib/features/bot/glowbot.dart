
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _CS();
}

class _CS extends State<ChatScreen> {
  final inp = TextEditingController();
  final scroll = ScrollController();

  final List<Map<String, String>> chatMsgs = [];

  bool busy = false;
  bool loadingServices = true;
  String ctx = '';

  @override
  void initState() {
    super.initState();
    loadServices().then((_) => addGreeting());
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  /// Sapaan pertama dari GlowBot (tidak dikirim ke API Gemini).
  Future<void> addGreeting() async {
    String name = '';

    try {
      final r = await qry('SELECT nama FROM users WHERE id = ?', [myId]);
      if (r.isNotEmpty) {
        name = (r.first['nama'] ?? '').toString().trim();
      }
    } catch (_) {}

    if (!mounted || chatMsgs.isNotEmpty) return;

    setState(() {
      chatMsgs.add({
        'role': 'model',
        'greeting': '1',
        'text': '${_timeGreeting()}${name.isEmpty ? '' : ', $name'}! 👋\n'
            'Aku GlowBot, asisten virtual GlowClinic. Aku bisa bantu soal '
            'pilihan layanan, persiapan sebelum treatment, dan perawatan '
            'setelahnya.\n\nAda yang ingin kamu tanyakan hari ini?',
      });
    });
  }

  Future<void> loadServices() async {
    try {
      final services = await qry(
        'SELECT nama, kategori FROM treatments',
      );

      if (!mounted) return;

      setState(() {
        ctx = services
            .map((t) => '${t['nama']} (${t['kategori']})')
            .join(', ');
        loadingServices = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        ctx = '';
        loadingServices = false;
      });
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;

      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _thinkingOk = true;

  /// Memanggil Gemini. Token thinking ikut dihitung dalam maxOutputTokens,
  /// jadi thinking dibuat minimal (tercepat) dan batas token dibuat longgar.
  Future<http.Response> _call() {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/'
      'v1beta/models/$kModel:generateContent?key=$kGemini',
    );

    return http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {
                  'text':
                      'Kamu GlowBot, asisten virtual klinik kecantikan '
                      'GlowClinic. Jawab singkat dan ramah dalam bahasa '
                      'Indonesia seputar layanan, persiapan, dan perawatan '
                      'setelah treatment. Jangan mendiagnosis penyakit atau '
                      'menggantikan dokter. Untuk keluhan medis, sarankan '
                      'konsultasi dengan dokter. Jangan mengarang layanan '
                      'atau harga. Layanan klinik yang tersedia: '
                      '${ctx.isEmpty ? 'Data layanan belum tersedia.' : ctx}.',
                },
              ],
            },
            'contents': [
              for (final message
                  in chatMsgs.where((m) => m['greeting'] != '1'))
                {
                  'role': message['role'],
                  'parts': [
                    {'text': message['text']},
                  ],
                },
            ],
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 2048,
              if (_thinkingOk) 'thinkingConfig': {'thinkingLevel': 'minimal'},
            },
          }),
        )
        .timeout(const Duration(seconds: 40));
  }

  Future<void> send() async {
    final question = inp.text.trim();

    if (question.isEmpty || busy) return;

    inp.clear();

    setState(() {
      chatMsgs.add({
        'role': 'user',
        'text': question,
      });
      busy = true;
    });

    scrollToBottom();

    String answer;

    if (kGemini.trim().isEmpty) {
      answer =
          'GlowBot belum dikonfigurasi. '
          'Tambahkan GEMINI_KEY melalui --dart-define '
          'saat menjalankan aplikasi.';

      if (!mounted) return;

      setState(() {
        chatMsgs.add({
          'role': 'model',
          'text': answer,
        });
        busy = false;
      });

      scrollToBottom();
      return;
    }

    try {
      var response = await _call();

      // Jika konfigurasi thinking ditolak, ulangi tanpa thinkingConfig.
      if (response.statusCode == 400 &&
          _thinkingOk &&
          response.body.toLowerCase().contains('thinking')) {
        _thinkingOk = false;
        response = await _call();
      }

      // Server sibuk / kuota sesaat: coba sekali lagi.
      if (response.statusCode == 503 || response.statusCode == 429) {
        await Future.delayed(const Duration(seconds: 2));
        response = await _call();
      }

      if (response.statusCode != 200) {
        // Menampilkan error asli Gemini di terminal VS Code.
        debugPrint('GEMINI STATUS: ${response.statusCode}');
        debugPrint('GEMINI ERROR: ${response.body}');

        String detail = 'Tidak ada detail error dari server.';

        try {
          final errorData = jsonDecode(response.body);

          if (errorData is Map &&
              errorData['error'] is Map) {
            detail =
                errorData['error']['message']?.toString() ??
                    detail;
          }
        } catch (_) {}

        if (response.statusCode == 503) {
          answer =
              'Layanan Gemini sedang sibuk. Coba lagi nanti. '
              'Detail: $detail';
        } else if (response.statusCode == 429) {
          answer =
              'Batas penggunaan Gemini tercapai. '
              'Periksa kuota API. Detail: $detail';
        } else if (response.statusCode == 400 ||
            response.statusCode == 404) {
          answer =
              'Permintaan Gemini tidak valid '
              '(HTTP ${response.statusCode}). '
              'Detail: $detail';
        } else if (response.statusCode == 401 ||
            response.statusCode == 403) {
          answer =
              'API key ditolak atau tidak memiliki izin. '
              'Periksa konfigurasi API key.';
        } else {
          answer =
              'GlowBot gagal merespons '
              '(HTTP ${response.statusCode}). '
              'Detail: $detail';
        }
      } else {
        final data = jsonDecode(response.body);

        final candidates =
            data is Map ? data['candidates'] : null;

        final firstCandidate =
            candidates is List && candidates.isNotEmpty
                ? candidates.first
                : null;

        final content =
            firstCandidate is Map
                ? firstCandidate['content']
                : null;

        final parts =
            content is Map ? content['parts'] : null;

        if (parts is List && parts.isNotEmpty) {
          answer = parts
              .where(
                (part) =>
                    part is Map && part['text'] is String,
              )
              .map(
                (part) => part['text'] as String,
              )
              .join('\n')
              .trim();

          if (answer.isEmpty) {
            answer =
                'GlowBot belum dapat memberikan jawaban. '
                'Silakan coba pertanyaan lain.';
          }
        } else {
          answer =
              'GlowBot tidak dapat menjawab pertanyaan ini. '
              'Coba gunakan pertanyaan yang berbeda.';
        }
      }
    } on TimeoutException {
      answer =
          'Koneksi terlalu lama. '
          'Periksa internet dan coba lagi.';
    } catch (e) {
      debugPrint('GEMINI CONNECTION ERROR: $e');

      answer =
          'Gagal terhubung ke GlowBot. '
          'Periksa koneksi internet dan konfigurasi API.';
    }

    if (!mounted) return;

    setState(() {
      chatMsgs.add({
        'role': 'model',
        'text': answer,
      });
      busy = false;
    });

    scrollToBottom();
  }

  @override
  void dispose() {
    inp.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            children: [
              for (final message in chatMsgs)
                _Bubble(
                  text: message['text'] ?? '',
                  mine: message['role'] == 'user',
                ),
              if (busy) const _TypingBubble(),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: Text(
            'GlowBot bukan alat diagnosis medis. '
            'Konsultasikan keluhan kepada dokter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inp,
                  onSubmitted: (_) => send(),
                  textInputAction: TextInputAction.send,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    hintText: 'Tulis pertanyaan...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Kirim pesan',
                icon: const Icon(Icons.send),
                onPressed: busy ? null : send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gelembung chat gaya WhatsApp.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFFFD6E3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: SelectableText(text),
      ),
    );
  }
}

/// Tiga titik berdenyut saat menunggu balasan (seperti "sedang mengetik" di WA).
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Tiap titik bergeser fase agar menyala bergantian (kiri ke kanan).
                final t = (_c.value - i * 0.18) % 1.0;

                // 0 -> 1 -> 0 dalam separuh siklus, lalu istirahat.
                final double wave =
                    t < 0.5 ? (1 - (t * 4 - 1).abs()).clamp(0.0, 1.0).toDouble() : 0.0;

                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Transform.translate(
                    offset: Offset(0, -3 * wave),
                    child: Opacity(
                      opacity: 0.35 + 0.65 * wave,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF8696A0),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
