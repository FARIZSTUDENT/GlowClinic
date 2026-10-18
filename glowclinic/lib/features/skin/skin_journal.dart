import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:light/light.dart';
import 'package:path_provider/path_provider.dart';
import 'package:glowclinic/core/core.dart';

class PhotoScreen extends StatefulWidget {
  final Map b;

  const PhotoScreen(this.b, {super.key});

  @override
  State<PhotoScreen> createState() => _PS();
}

class _PS extends State<PhotoScreen> {
  double? lux;
  StreamSubscription? sub;
  List<Map<String, dynamic>> ph = [];

  bool loading = true;
  bool takingPhoto = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _listenToLight();
    load();
  }

  void _listenToLight() {
    try {
      sub = Light().lightSensorStream.listen(
        (value) {
          if (!mounted) return;
          setState(() {
            lux = (value as num).toDouble();
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            lux = null;
          });
        },
      );
    } catch (_) {
      lux = null;
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }

    try {
      final rows = await qry(
        'select * from record_photos '
        'where booking_id = ? order by id',
        [widget.b['id']],
      );

      final photos = List<Map<String, dynamic>>.from(rows);

      if (!mounted) return;

      setState(() {
        ph = photos;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadError = 'Gagal memuat foto jurnal.';
        loading = false;
      });
    }
  }

  // Jika sensor tidak tersedia, foto tetap diizinkan.
  bool get ok => lux == null || lux! >= 100;

  String _luxText(dynamic value) {
    if (value == null) return '-';

    final number = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    return number?.toStringAsFixed(0) ?? '-';
  }

  Future<void> snapPhoto(String type) async {
    if (takingPhoto) return;

    if (!ok) {
      snack(context, 'Cahaya terlalu rendah. Cari tempat lebih terang.');
      return;
    }

    setState(() {
      takingPhoto = true;
    });

    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (x == null || !mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/rec_${widget.b['id']}_${type}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await File(x.path).copy(path);

      await db.insert('record_photos', {
        'booking_id': widget.b['id'],
        'tipe': type,
        'photo_path': path,
        'lux': lux,
      });

      if (!mounted) return;

      snack(context, 'Foto $type berhasil disimpan.');
      await load();
    } catch (_) {
      if (mounted) {
        snack(
          context,
          'Gagal mengambil atau menyimpan foto. '
          'Periksa izin kamera dan penyimpanan.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          takingPhoto = false;
        });
      }
    }
  }

  Widget _photoCard(Map<String, dynamic> photo) {
    final path = photo['photo_path']?.toString() ?? '';
    final type = photo['tipe']?.toString() ?? 'foto';
    final file = File(path);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (path.isNotEmpty && file.existsSync())
            Image.file(
              file,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(child: Text('Foto tidak dapat ditampilkan.')),
              ),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.broken_image, size: 40)),
            ),
          ListTile(
            title: Text(type.toUpperCase()),
            subtitle: Text('Cahaya saat foto: ${_luxText(photo['lux'])} lux'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightAvailable = lux != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Skin Journal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: !lightAvailable
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : ok
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: ListTile(
              leading: Icon(
                Icons.light_mode,
                color: !lightAvailable
                    ? null
                    : ok
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(
                lightAvailable
                    ? 'Cahaya: ${lux!.toStringAsFixed(0)} lux'
                    : 'Sensor cahaya tidak tersedia',
              ),
              subtitle: Text(
                !lightAvailable
                    ? 'Foto tetap diizinkan tanpa pengukuran sensor.'
                    : ok
                    ? 'Cahaya memenuhi batas minimum 100 lux.'
                    : 'Terlalu gelap. Cari tempat lebih terang.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: ok && !takingPhoto
                      ? () => snapPhoto('before')
                      : null,
                  child: const Text('Foto Before'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: ok && !takingPhoto
                      ? () => snapPhoto('after')
                      : null,
                  child: const Text('Foto After'),
                ),
              ),
            ],
          ),
          if (takingPhoto)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (loadError != null)
            Column(
              children: [
                Text(loadError!),
                TextButton(onPressed: load, child: const Text('Coba Lagi')),
              ],
            )
          else if (ph.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada foto treatment.'),
              ),
            )
          else
            for (final photo in ph) _photoCard(photo),
        ],
      ),
    );
  }
}
