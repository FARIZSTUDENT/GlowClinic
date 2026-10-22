import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/config.dart';

/// Helper Service untuk komunikasi dengan Google Gemini API
class GlowBotService {
  static const String endpointBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Membangun System Prompt yang kaya dengan data riil GlowClinic
  static String buildSystemPrompt({
    List<Map<String, dynamic>> treatments = const [],
    List<Map<String, dynamic>> branches = const [],
    List<Map<String, dynamic>> doctors = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Kamu adalah GlowBot, asisten virtual resmi untuk GlowClinic (klinik estetika dan perawatan kulit).',
    );
    buffer.writeln(
      'Kepribadianmu: Ramah, hangat, sopan, informatif, profesional, dan empatik menggunakan Bahasa Indonesia yang natural.',
    );
    buffer.writeln('');
    buffer.writeln('PEDOMAN DAN ATURAN UTAMA:');
    buffer.writeln(
      '1. SAPAAN: Balas sapaan pengguna (seperti "hai", "halo", "selamat pagi/siang/sore/malam") dengan hangat, sebut dirimu GlowBot, dan tanyakan apa yang dapat kamu bantu hari ini seputar perawatan di GlowClinic.',
    );
    buffer.writeln(
      '2. INFORMASI TREATMENT: Jelaskan layanan treatment yang tersedia, manfaat, kategori, estimasi durasi, dan harga dalam IDR (Rupiah) berdasarkan data resmi berikut.',
    );
    buffer.writeln(
      '3. PERSIAPAN SEBELUM TREATMENT (PRE-TREATMENT): '
      'Berikan panduan umum persiapan, misalnya: pastikan kulit bersih, hindari paparan sinar matahari terik sebelum treatment, dan hentikan pemakaian zat eksfoliasi kuat (seperti AHA, BHA, atau Retinol) 2-3 hari sebelum treatment laser atau peeling.',
    );
    buffer.writeln(
      '4. PERAWATAN SETELAH TREATMENT (AFTERCARE): '
      'Berikan panduan aftercare, misalnya: wajib menggunakan sunscreen minimal SPF 30, rutin memakai pelembap (moisturizer), hindari memencet atau mengelupas kulit, hindari makeup tebal selama 24 jam pertama, dan hindari eksfoliasi keras selama beberapa hari.',
    );
    buffer.writeln(
      '5. ALUR BOOKING: '
      'Jika pengguna menanyakan cara reservasi atau booking, jelaskan langkahnya di aplikasi GlowClinic: '
      'Buka tab menu "Booking" di navigasi bawah -> Pilih Cabang -> Pilih Treatment -> Pilih Tanggal -> Pilih Dokter yang tersedia -> Pilih Slot Jam yang kosong -> Konfirmasi Booking.',
    );
    buffer.writeln(
      '6. CABANG & JAM BUKA: Berikan informasi cabang resmi GlowClinic, alamat, dan jam buka operasional sesuai data berikut.',
    );
    buffer.writeln(
      '7. DOKTER & JADWAL: Berikan informasi dokter, spesialisasi, dan jadwal praktik sesuai data resmi berikut. Jangan mengarang dokter di luar data.',
    );
    buffer.writeln(
      '8. BATASAN MEDIS (DISCLAIMER PENTING): '
      'Kamu adalah asisten virtual, BUKAN dokter. JANGAN memberikan diagnosis medis pasti atas keluhan penyakit kulit atau meresepkan obat keras. Untuk kondisi kulit spesifik atau keluhan medis serius, selalu sarankan pengguna untuk berkonsultasi langsung dengan dokter spesialis di GlowClinic.',
    );
    buffer.writeln(
      '9. KEJUJURAN DATA: Jangan mengarang harga atau jadwal yang tidak ada di data resmi klinik. Jika pengguna menanyakan ketersediaan slot detik ini, arahkan untuk memeriksa ketersediaan live di tab Booking aplikasi.',
    );
    buffer.writeln('');
    buffer.writeln('--- DATA RESMI GLOWCLINIC ---');

    buffer.writeln('LAYANAN & TREATMENT TERSEDIA:');
    if (treatments.isEmpty) {
      buffer.writeln('  * Facial Medis (Kategori: Facial, Durasi: 60 menit, Harga: Rp 350.000): Pembersihan mendalam dan perawatan kesehatan kulit wajah.');
      buffer.writeln('  * Laser Rejuvenation (Kategori: Laser, Durasi: 45 menit, Harga: Rp 1.200.000): Peremajaan kulit wajah dengan teknologi laser terkini.');
      buffer.writeln('  * Chemical Peeling (Kategori: Peeling, Durasi: 40 menit, Harga: Rp 600.000): Pengelupasan lapisan sel kulit mati terkendali untuk regenerasi kulit.');
      buffer.writeln('  * Konsultasi Dokter (Kategori: Konsultasi, Durasi: 20 menit, Harga: Rp 150.000): Konsultasi mendalam kondisi kulit bersama dokter ahli.');
    } else {
      for (final t in treatments) {
        final nama = t['nama'] ?? '';
        final kat = t['kategori'] ?? '';
        final durasi = t['durasi_menit'] ?? 0;
        final harga = t['harga_idr'] ?? 0;
        final desc = t['deskripsi'] ?? '';
        buffer.writeln('  * $nama (Kategori: $kat, Durasi: $durasi menit, Harga: Rp $harga): $desc');
      }
    }

    buffer.writeln('CABANG KLINIK & JAM BUKA:');
    if (branches.isEmpty) {
      buffer.writeln('  * GlowClinic Pusat: Area pusat Kota Yogyakarta (Jam operasional: 09:00 - 18:00)');
      buffer.writeln('  * GlowClinic Sleman: Area Sleman, Yogyakarta (Jam operasional: 09:00 - 18:00)');
      buffer.writeln('  * GlowClinic Bantul: Area Bantul, Yogyakarta (Jam operasional: 09:00 - 18:00)');
    } else {
      for (final b in branches) {
        final nama = b['nama'] ?? '';
        final alamat = b['alamat'] ?? '';
        final jam = b['jam_buka'] ?? '09:00 - 18:00';
        buffer.writeln('  * $nama: $alamat (Jam operasional: $jam)');
      }
    }

    buffer.writeln('TIM DOKTER & JADWAL:');
    if (doctors.isEmpty) {
      buffer.writeln('  * dr. Rina Aulia, Sp.KK (Dermatologi): Pemeriksaan dan perawatan kesehatan kulit.');
      buffer.writeln('  * dr. Bima Pratama (Estetika): Perawatan dan estetika kulit wajah.');
      buffer.writeln('  * dr. Nadia Putri (Dermatologi): Spesialis kondisi kulit dan jerawat.');
    } else {
      for (final d in doctors) {
        final nama = d['nama'] ?? '';
        final spesialisasi = d['spesialisasi'] ?? '';
        final jadwal = d['jadwal_praktik'] ?? '';
        final desc = d['deskripsi'] ?? '';
        buffer.writeln('  * $nama ($spesialisasi) - Jadwal: $jadwal. $desc');
      }
    }

    return buffer.toString().trim();
  }

  /// Mengirim pesan ke Gemini API dan mengembalikan balasan teks
  static Future<String> generateReply({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String userMessage,
    http.Client? client,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      return 'GlowBot belum dikonfigurasi.\n'
          'Tambahkan GEMINI_KEY melalui --dart-define saat menjalankan aplikasi.\n\n'
          'Contoh perintah:\n'
          'flutter run --dart-define=GEMINI_KEY=AIzaSy...';
    }

    final trimmedMsg = userMessage.trim();
    if (trimmedMsg.isEmpty) {
      return 'Silakan tulis pertanyaan kamu.';
    }

    // Bangun daftar 'contents' yang sesuai spesifikasi Gemini API:
    // - Role bergantian: user -> model -> user -> model.
    // - Pesan pertama HARUS role 'user'.
    // - Abaikan pesan greeting atau pesan error.
    final List<Map<String, dynamic>> contents = [];

    final validHistory = history.where((m) {
      final role = m['role'];
      final isGreeting = m['greeting'] == '1';
      final isError = m['error'] == '1';
      final text = (m['text'] ?? '').trim();
      return (role == 'user' || role == 'model') &&
          !isGreeting &&
          !isError &&
          text.isNotEmpty;
    }).toList();

    // Batasi histori percakapan 8 pesan terakhir agar cepat dan hemat token
    final recentHistory = validHistory.length > 8
        ? validHistory.sublist(validHistory.length - 8)
        : validHistory;

    String? lastRole;
    for (final item in recentHistory) {
      final role = item['role']!;
      final text = item['text']!;
      if (contents.isEmpty) {
        if (role == 'user') {
          contents.add({
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          });
          lastRole = 'user';
        }
      } else {
        if (role != lastRole) {
          contents.add({
            'role': role,
            'parts': [
              {'text': text},
            ],
          });
          lastRole = role;
        }
      }
    }

    // Masukkan pesan pengguna saat ini
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      contents.last = {
        'role': 'user',
        'parts': [
          {'text': trimmedMsg},
        ],
      };
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': trimmedMsg},
        ],
      });
    }

    final httpClient = client ?? http.Client();
    final bool shouldCloseClient = client == null;

    try {
      final uri = Uri.parse(
        '$endpointBase/$model:generateContent?key=$trimmedKey',
      );

      final payload = {
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        },
      };

      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'x-goog-api-key': trimmedKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return _extractAnswer(decoded);
      }

      return _handleApiError(response.statusCode, response.body);
    } on TimeoutException {
      return 'Koneksi ke GlowBot timeout (terlalu lama). Periksa koneksi internet Anda dan coba lagi.';
    } on http.ClientException {
      return 'Gagal terhubung ke GlowBot. Periksa koneksi internet Anda.';
    } catch (e) {
      debugPrint('GlowBot connection error: $e');
      return 'Terjadi kendala saat menghubungi GlowBot. Silakan coba kembali beberapa saat lagi.';
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  static String _extractAnswer(dynamic decoded) {
    if (decoded is! Map) {
      return 'GlowBot belum dapat memberikan jawaban. Silakan coba pertanyaan lain.';
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final promptFeedback = decoded['promptFeedback'];
      if (promptFeedback is Map && promptFeedback['blockReason'] != null) {
        return 'Pertanyaan tidak dapat diproses karena kebijakan keamanan konten AI (${promptFeedback['blockReason']}).';
      }
      return 'GlowBot belum dapat memberikan jawaban. Silakan coba pertanyaan lain.';
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map) {
      return 'GlowBot belum dapat memberikan jawaban. Silakan coba pertanyaan lain.';
    }

    final finishReason = firstCandidate['finishReason'];
    if (finishReason == 'SAFETY') {
      return 'Maaf, jawaban tidak dapat ditampilkan karena kebijakan keamanan konten AI.';
    }

    final content = firstCandidate['content'];
    if (content is! Map) {
      return 'GlowBot belum dapat memberikan jawaban. Silakan coba pertanyaan lain.';
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return 'GlowBot tidak dapat menemukan respons untuk pertanyaan ini.';
    }

    final text = parts
        .where((part) => part is Map && part['text'] is String)
        .map((part) => (part as Map)['text'] as String)
        .join('\n')
        .trim();

    if (text.isEmpty) {
      return 'GlowBot belum dapat memberikan jawaban. Silakan coba pertanyaan lain.';
    }

    return text;
  }

  static String _handleApiError(int statusCode, String responseBody) {
    String detail = '';
    try {
      final err = jsonDecode(responseBody);
      if (err is Map && err['error'] is Map) {
        detail = (err['error']['message'] ?? '').toString();
      }
    } catch (_) {}

    // Jangan pernah membocorkan token / api key dalam pesan error
    if (detail.toLowerCase().contains('key') && detail.toLowerCase().contains('api')) {
      detail = 'Otentikasi API key tidak valid.';
    }

    switch (statusCode) {
      case 400:
        return 'Permintaan ke AI tidak valid (HTTP 400). Mohon periksa kembali pertanyaan Anda.';
      case 401:
      case 403:
        return 'API key Gemini tidak valid atau tidak memiliki izin akses (HTTP $statusCode). '
            'Pastikan GEMINI_KEY yang digunakan valid dan aktif dari Google AI Studio.';
      case 404:
        return 'Model AI tidak ditemukan (HTTP 404). '
            'Pastikan model Gemini yang digunakan valid (default: gemini-1.5-flash).';
      case 429:
        return 'Batas kuota penggunaan Gemini API tercapai (HTTP 429). '
            'Silakan tunggu beberapa saat lagi sebelum mencoba kembali.';
      case 500:
      case 503:
        return 'Server Gemini sedang sibuk atau mengalami gangguan sementara (HTTP $statusCode). '
            'Silakan coba kembali sesaat lagi.';
      default:
        return 'GlowBot gagal merespons (HTTP $statusCode). Silakan coba lagi.';
    }
  }
}

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
            'Aku GlowBot, asisten virtual GlowClinic. Aku bisa bantu info seputar '
            'pilihan treatment, persiapan sebelum tindakan, perawatan setelahnya, '
            'serta info cabang dan jadwal dokter.\n\n'
            'Ada yang ingin kamu tanyakan hari ini?',
      });
    });
  }

  Future<void> loadServices() async {
    try {
      final treatments = await qry(
        'SELECT nama, kategori, deskripsi, durasi_menit, harga_idr FROM treatments ORDER BY nama',
      );
      final branches = await qry(
        'SELECT nama, alamat, jam_buka FROM branches ORDER BY id',
      );
      final doctors = await qry(
        'SELECT nama, spesialisasi, pengalaman_tahun, deskripsi, jadwal_praktik FROM doctors ORDER BY nama',
      );

      if (!mounted) return;

      setState(() {
        ctx = GlowBotService.buildSystemPrompt(
          treatments: treatments,
          branches: branches,
          doctors: doctors,
        );
        loadingServices = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        ctx = GlowBotService.buildSystemPrompt();
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

  Future<void> send([String? customText]) async {
    final question = (customText ?? inp.text).trim();

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

    // Pastikan System Prompt sudah siap
    final systemPrompt = ctx.isNotEmpty
        ? ctx
        : GlowBotService.buildSystemPrompt();

    final answer = await GlowBotService.generateReply(
      apiKey: kGemini,
      model: kModel,
      systemPrompt: systemPrompt,
      history: chatMsgs,
      userMessage: question,
    );

    if (!mounted) return;

    final isError = answer.contains('belum dikonfigurasi') ||
        answer.contains('gagal') ||
        answer.contains('tidak valid');

    setState(() {
      chatMsgs.add({
        'role': 'model',
        'text': answer,
        if (isError) 'error': '1',
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
        // Rekomendasi Pertanyaan Cepat untuk Pengguna
        if (chatMsgs.length <= 1 && !busy)
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _QuickChip(
                  label: '💆‍♀️ Layanan & Harga',
                  onTap: () => send('Apa saja layanan treatment dan harganya di GlowClinic?'),
                ),
                _QuickChip(
                  label: '📍 Cabang & Jam Buka',
                  onTap: () => send('Di mana saja lokasi cabang GlowClinic dan jam bukanya?'),
                ),
                _QuickChip(
                  label: '📅 Cara Booking',
                  onTap: () => send('Bagaimana cara booking treatment di aplikasi?'),
                ),
                _QuickChip(
                  label: '✨ Tips Perawatan Wajah',
                  onTap: () => send('Apa persiapan sebelum melakukan facial atau laser?'),
                ),
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
                  onSubmitted: busy ? null : (_) => send(),
                  textInputAction: TextInputAction.send,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    hintText: 'Tulis pertanyaan...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Kirim pesan',
                icon: Icon(
                  Icons.send_rounded,
                  color: busy ? Colors.grey : const Color(0xFF87364B),
                ),
                onPressed: busy ? null : () => send(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip pertanyaan cepat untuk mempermudah pengguna bertanya
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF87364B),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFFFFE8EF),
        side: const BorderSide(color: Color(0xFFFFD1DE)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onPressed: onTap,
      ),
    );
  }
}

/// Gelembung chat gaya WhatsApp dengan tema GlowClinic.
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: mine ? const Color(0xFF333333) : const Color(0xFF222222),
          ),
        ),
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
                final t = (_c.value - i * 0.18) % 1.0;
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
