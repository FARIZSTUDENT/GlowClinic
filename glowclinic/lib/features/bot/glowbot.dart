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
    loadServices();
  }

  Future<void> loadServices() async {
    try {
      final services = await qry('SELECT nama, kategori FROM treatments');

      if (!mounted) return;

      setState(() {
        ctx = services.map((t) => '${t['nama']} (${t['kategori']})').join(', ');
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

  Future<void> send() async {
    final question = inp.text.trim();

    if (question.isEmpty || busy) return;

    inp.clear();

    setState(() {
      chatMsgs.add({'role': 'user', 'text': question});
      busy = true;
    });

    scrollToBottom();

    String answer;

    if (kGemini.trim().isEmpty) {
      answer = 'GlowBot belum dikonfigurasi. Tambahkan GEMINI_KEY melalui --dart-define saat menjalankan aplikasi.';
      if (!mounted) return;
      setState(() {
        chatMsgs.add({'role': 'model', 'text': answer});
        busy = false;
      });
      scrollToBottom();
      return;
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/'
        'v1beta/models/$kModel:generateContent?key=$kGemini',
      );

      final response = await http
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
                for (final message in chatMsgs)
                  {
                    'role': message['role'],
                    'parts': [
                      {'text': message['text']},
                    ],
                  },
              ],
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 500},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        if (response.statusCode == 503) {
          answer = 'Layanan Gemini sedang sibuk atau model belum tersedia (HTTP 503). Tunggu sebentar lalu coba lagi. Jika terus terjadi, periksa nama model dan kuota API key.';
        } else if (response.statusCode == 429) {
          answer = 'Batas penggunaan Gemini tercapai (HTTP 429). Coba lagi nanti atau periksa kuota API.';
        } else if (response.statusCode == 400 || response.statusCode == 404) {
          answer = 'Konfigurasi Gemini tidak valid (HTTP ${response.statusCode}). Periksa nama model dan API key.';
        } else {
          answer = 'GlowBot gagal merespons (HTTP ${response.statusCode}). Coba lagi nanti.';
        }
      } else {
        final data = jsonDecode(response.body);

        final candidates = data is Map ? data['candidates'] : null;

        final firstCandidate = candidates is List && candidates.isNotEmpty
            ? candidates.first
            : null;
        final content = firstCandidate is Map
            ? firstCandidate['content']
            : null;
        final parts = content is Map ? content['parts'] : null;

        if (parts is List && parts.isNotEmpty) {
          answer = parts
              .where((part) => part is Map && part['text'] is String)
              .map((part) => part['text'] as String)
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
      answer = 'Koneksi terlalu lama. Periksa internet dan coba lagi.';
    } catch (_) {
      answer =
          'Gagal terhubung ke GlowBot. '
          'Periksa koneksi internet dan konfigurasi API.';
    }

    if (!mounted) return;

    setState(() {
      chatMsgs.add({'role': 'model', 'text': answer});
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
              if (chatMsgs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    loadingServices
                        ? 'Halo! Aku GlowBot. Sedang memuat informasi layanan...'
                        : 'Halo! Aku GlowBot. Tanya soal persiapan '
                              'atau perawatan setelah treatment.',
                  ),
                ),
              for (final message in chatMsgs)
                Align(
                  alignment: message['role'] == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Card(
                    color: message['role'] == 'user'
                        ? Colors.pink.shade100
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: SelectableText(message['text'] ?? ''),
                      ),
                    ),
                  ),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            'GlowBot bukan alat diagnosis medis. '
            'Konsultasikan keluhan kepada dokter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
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
