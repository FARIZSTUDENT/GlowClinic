import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/blockchain/chain.dart';

class BookingScreen extends StatefulWidget {
  final Map t;

  const BookingScreen(this.t, {super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Map<String, dynamic>> docs = [];
  Map<String, dynamic>? doc;
  DateTime? when;

  bool loadingDoctors = true;
  bool saving = false;
  String? doctorError;

  @override
  void initState() {
    super.initState();
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    try {
      final result = await qry('select * from doctors');

      if (!mounted) {
        return;
      }

      setState(() {
        docs = List<Map<String, dynamic>>.from(result);
        loadingDoctors = false;
        doctorError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingDoctors = false;
        doctorError = 'Gagal memuat daftar dokter.';
      });
    }
  }

  Future<void> pick() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: when != null && when!.isAfter(now)
          ? DateTime(when!.year, when!.month, when!.day)
          : DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: when != null
          ? TimeOfDay.fromDateTime(when!)
          : const TimeOfDay(hour: 10, minute: 0),
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!selectedDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jadwal yang masih akan datang.')),
      );
      return;
    }

    setState(() {
      when = selectedDateTime;
    });
  }

  Future<void> save() async {
    if (saving || doc == null || when == null) {
      return;
    }

    final utc = when!.toUtc();

    setState(() {
      saving = true;
    });

    var bookingSaved = false;

    try {
      final id = await db.insert('bookings', {
        'user_id': myId,
        'doctor_id': doc!['id'],
        'branch_id': doc!['branch_id'],
        'treatment_id': widget.t['id'],
        'waktu_utc': utc.toIso8601String(),
        'total_idr': widget.t['harga_idr'],
      });

      bookingSaved = true;

      // Catat booking ke blockchain setelah database berhasil menyimpan.
      await Chain.add('booking:$id:$myId:${utc.toIso8601String()}');

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        'Booking berhasil dikirim dan menunggu konfirmasi.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = bookingSaved
          ? 'Booking tersimpan, tetapi pencatatan blockchain gagal. '
                'Jangan kirim booking ulang; periksa status pencatatan.'
          : 'Booking gagal disimpan. Silakan coba lagi.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Booking ${widget.t['nama'] ?? 'Layanan'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loadingDoctors)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (doctorError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctorError!),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: loadDoctors,
                  child: const Text('Muat Ulang Dokter'),
                ),
              ],
            )
          else if (docs.isEmpty)
            const Text('Belum ada dokter yang tersedia.')
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: doc,
              isExpanded: true,
              hint: const Text('Pilih dokter'),
              items: [
                for (final doctor in docs)
                  DropdownMenuItem<Map<String, dynamic>>(
                    value: doctor,
                    child: Text(
                      '${doctor['nama'] ?? 'Tanpa nama'} '
                      '(${doctor['spesialisasi'] ?? '-'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      setState(() {
                        doc = value;
                      });
                    },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving ? null : pick,
            icon: const Icon(Icons.calendar_month),
            label: Text(when == null ? 'Pilih tanggal & jam' : 'Ganti jadwal'),
          ),
          if (when != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(zoneText(when!.toUtc())),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: doc != null && when != null && !saving && !loadingDoctors
                ? save
                : null,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Konfirmasi Booking'),
          ),
        ],
      ),
    );
  }
}
