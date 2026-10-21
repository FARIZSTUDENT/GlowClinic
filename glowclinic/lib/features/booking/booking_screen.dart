import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/features/booking/zones.dart';
import 'package:glowclinic/features/blockchain/chain.dart';

const Color bookingPink = Color(0xFF641F35);
const Color bookingDark = Color(0xFF481526);
const Color bookingLight = Color(0xFFF3E4E8);
const Color bookingBackground = Color(0xFFFFF8F6);
const Color bookingText = Color(0xFF49343B);
const Color bookingMuted = Color(0xFF9A7B84);

class BookingScreen extends StatefulWidget {
  final Map t;

  const BookingScreen(this.t, {super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Map<String, dynamic>> branches = [];
  Map<String, dynamic>? branch;
  List<Map<String, dynamic>> docs = [];
  Map<String, dynamic>? doc;
  DateTime? when;

  bool loadingBranches = true;
  bool loadingDoctors = true;
  bool saving = false;
  String? branchError;
  String? doctorError;
  late String selectedCurrency;

  @override
  void initState() {
    super.initState();
    selectedCurrency = CurrencyService.activeCurrency.value;
    loadBranches();
  }

  Future<void> loadBranches() async {
    setState(() {
      loadingBranches = true;
      branchError = null;
    });

    try {
      final result = await qry('select * from branches order by id');

      if (!mounted) return;

      setState(() {
        branches = List<Map<String, dynamic>>.from(result);
        branch = branches.isNotEmpty ? branches.first : null;
        loadingBranches = false;
      });

      if (branch != null) {
        await loadDoctors();
      } else {
        setState(() {
          loadingDoctors = false;
          doctorError = 'Belum ada cabang yang tersedia.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingBranches = false;
        branchError = 'Gagal memuat daftar cabang.';
        loadingDoctors = false;
      });
    }
  }

  Future<void> selectBranch(Map<String, dynamic>? value) async {
    if (value == null || saving) return;
    setState(() {
      branch = value;
      doc = null;
      when = null;
    });
    await loadDoctors();
  }

  Future<void> loadDoctors() async {
    setState(() {
      loadingDoctors = true;
      doctorError = null;
    });

    try {
      if (branch == null) {
        setState(() {
          docs = [];
          loadingDoctors = false;
        });
        return;
      }

      final result = await qry(
        'select * from doctors where branch_id = ? order by nama',
        [branch!['id']],
      );

      if (!mounted) return;

      setState(() {
        docs = List<Map<String, dynamic>>.from(result);
        loadingDoctors = false;

        // Pertahankan pilihan dokter jika masih ada di hasil query.
        if (doc != null) {
          final oldId = doc!['id'];
          doc = docs.cast<Map<String, dynamic>?>().firstWhere(
                (d) => d?['id'] == oldId,
                orElse: () => null,
              );
        }
      });
    } catch (_) {
      if (!mounted) return;

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
      initialDate: when != null &&
              DateUtils.dateOnly(when!).isAfter(DateUtils.dateOnly(now))
          ? DateUtils.dateOnly(when!)
          : DateUtils.dateOnly(now),
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(now.add(const Duration(days: 90))),
      helpText: 'Pilih tanggal perawatan',
      cancelText: 'BATAL',
      confirmText: 'LANJUT',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: bookingPink,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: bookingText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: when != null
          ? TimeOfDay.fromDateTime(when!)
          : const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Pilih jam perawatan',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: bookingPink,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: bookingText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!selectedDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih jadwal yang masih akan datang.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      when = selectedDateTime;
    });
  }

  Future<void> save() async {
    if (saving || doc == null || when == null) return;

    final utc = when!.toUtc();

    setState(() {
      saving = true;
    });

    var bookingSaved = false;

    try {
      final priceIdr = (widget.t['harga_idr'] as num?)?.toInt() ?? 0;
      final rate = CurrencyService.getRate(selectedCurrency);
      final totalBayar = CurrencyService.convertFromIdr(
        priceIdr,
        selectedCurrency,
        customRate: rate,
      );

      final id = await db.insert('bookings', {
        'user_id': myId,
        'doctor_id': doc!['id'],
        'branch_id': branch!['id'],
        'treatment_id': widget.t['id'],
        'treatment_nama': widget.t['nama']?.toString(),
        'waktu_utc': utc.toIso8601String(),
        'total_idr': priceIdr,
        'mata_uang': selectedCurrency,
        'kurs': rate,
        'total_bayar': totalBayar,
      });

      bookingSaved = true;
      bookingRefresh.value++; // daftar booking langsung memuat ulang

      try {
        final me = await qry('select nama from users where id = ?', [myId]);
        final who = me.isEmpty ? 'Pasien' : '${me.first['nama']}';

        final displayPrice = CurrencyService.formatMoney(
          totalBayar,
          selectedCurrency,
        );
        final priceSummary = selectedCurrency == 'IDR'
            ? 'Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')}'
            : '$displayPrice (Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')})';

        await pushNotif(
          toStaff: true,
          judul: 'Booking baru 📅',
          isi: '$who memesan ${widget.t['nama']} seharga $priceSummary pada '
              '${fmtDateTime(utc.toIso8601String())}. Segera Acc atau Tolak.',
          tipe: 'booking',
          bookingId: id,
        );
      } catch (_) {}

      await Chain.add(
        'booking:$id:$myId:$selectedCurrency:$totalBayar:$priceIdr:${utc.toIso8601String()}',
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        'Booking berhasil dikirim dan menunggu konfirmasi.',
      );
    } catch (_) {
      if (!mounted) return;

      final message = bookingSaved
          ? 'Booking sudah tersimpan, tetapi pencatatan blockchain gagal. '
              'Jangan kirim booking ulang; periksa status pencatatan.'
          : 'Booking gagal disimpan. Silakan coba lagi.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bookingDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  String formatPrice(dynamic value) {
    final number = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');

    if (number == null) return '-';

    final digits = number.toString();
    final result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      result.write(digits[i]);

      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        result.write('.');
      }
    }

    return result.toString();
  }

  String formatDate(DateTime date) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${days[date.weekday - 1]}, ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute WIB';
  }

  @override
  Widget build(BuildContext context) {
    final treatmentName =
        widget.t['nama']?.toString() ?? 'Treatment';
    final category =
        widget.t['kategori']?.toString() ?? 'Perawatan kulit';
    final description =
        widget.t['deskripsi']?.toString() ?? '';
    final duration =
        widget.t['durasi_menit']?.toString() ?? '-';
    final priceIdr = (widget.t['harga_idr'] as num?)?.toInt() ?? 0;
    final totalBayar = CurrencyService.convertFromIdr(priceIdr, selectedCurrency);
    final formattedPrice = CurrencyService.formatMoney(totalBayar, selectedCurrency);
    final photo = widget.t['foto_url']?.toString().trim() ?? '';

    final canSubmit = branch != null &&
        doc != null &&
        when != null &&
        !saving &&
        !loadingDoctors &&
        !loadingBranches;

    return Scaffold(
      backgroundColor: bookingBackground,
      appBar: AppBar(
        backgroundColor: bookingBackground,
        foregroundColor: bookingText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Booking Perawatan',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: bookingText,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bookingPink, bookingDark],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktunya merawat diri',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Pilih dokter dan jadwal yang cocok untukmu.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Treatment yang dipilih', '01'),

            const SizedBox(height: 12),

            // RINGKASAN TREATMENT
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: bookingLight),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 100,
                      height: 105,
                      child: photo.startsWith('http')
                          ? Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: bookingLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: bookingPink,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          treatmentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: bookingText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: bookingMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$duration menit',
                              style: const TextStyle(
                                color: bookingMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedPrice,
                          style: const TextStyle(
                            color: bookingPink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (selectedCurrency != 'IDR') ...[
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')}',
                            style: const TextStyle(
                              color: bookingMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: bookingMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 26),

            _sectionTitle('Pilih cabang', '02'),

            const SizedBox(height: 12),

            // PILIH CABANG
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bookingLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: bookingLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: bookingPink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cabang GlowClinic',
                              style: TextStyle(
                                color: bookingText,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Pilih lokasi perawatanmu',
                              style: TextStyle(
                                color: bookingMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loadingBranches)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: bookingPink),
                      ),
                    )
                  else if (branchError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branchError!,
                          style: const TextStyle(color: bookingMuted),
                        ),
                        TextButton.icon(
                          onPressed: loadBranches,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    )
                  else if (branches.isEmpty)
                    const Text(
                      'Belum ada cabang yang tersedia.',
                      style: TextStyle(color: bookingMuted),
                    )
                  else
                    DropdownButtonFormField<Map<String, dynamic>>(
                      key: ValueKey(branch?['id']),
                      initialValue: branch,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Pilih cabang',
                        filled: true,
                        fillColor: bookingBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        for (final item in branches)
                          DropdownMenuItem<Map<String, dynamic>>(
                            value: item,
                            child: Text(
                              item['nama']?.toString() ?? 'Cabang',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: saving ? null : selectBranch,
                    ),
                  if (branch != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: bookingMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${branch!['alamat'] ?? 'Alamat belum tersedia'}'
                            '\nJam buka: ${branch!['jam_buka'] ?? '-'}',
                            style: const TextStyle(
                              color: bookingMuted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 26),

            _sectionTitle('Pilih dokter', '03'),

            const SizedBox(height: 12),

            // PILIH DOKTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bookingLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: bookingLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          color: bookingPink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dokter perawatan',
                              style: TextStyle(
                                color: bookingText,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Pilih dokter yang kamu inginkan',
                              style: TextStyle(
                                color: bookingMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loadingDoctors)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: bookingPink,
                        ),
                      ),
                    )
                  else if (doctorError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorError!,
                          style: const TextStyle(color: bookingMuted),
                        ),
                        TextButton.icon(
                          onPressed: loadDoctors,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    )
                  else if (docs.isEmpty)
                    const Text(
                      'Belum ada dokter yang tersedia.',
                      style: TextStyle(color: bookingMuted),
                    )
                  else
                    DropdownButtonFormField<Map<String, dynamic>>(
                      key: ValueKey(doc?['id']),
                      initialValue: doc,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Pilih dokter',
                        filled: true,
                        fillColor: bookingBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        for (final doctor in docs)
                          DropdownMenuItem<Map<String, dynamic>>(
                            value: doctor,
                            child: Text(
                              '${doctor['nama'] ?? 'Tanpa nama'}'
                              ' • ${doctor['spesialisasi'] ?? '-'}',
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
                ],
              ),
            ),

            const SizedBox(height: 26),

            _sectionTitle('Atur jadwal', '04'),

            const SizedBox(height: 12),

            // PILIH JADWAL
            InkWell(
              onTap: saving ? null : pick,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: when == null ? bookingLight : bookingPink,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bookingLight,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: bookingPink,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            when == null
                                ? 'Tanggal & waktu'
                                : formatDate(when!),
                            style: const TextStyle(
                              color: bookingText,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            when == null
                                ? 'Ketuk untuk memilih jadwal'
                                : '${formatTime(when!)} • ${zoneText(when!.toUtc())}',
                            style: const TextStyle(
                              color: bookingMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      when == null
                          ? Icons.add_circle_outline_rounded
                          : Icons.edit_calendar_rounded,
                      color: bookingPink,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 26),

            // RINGKASAN PEMBAYARAN
            _sectionTitle('Ringkasan booking', '05'),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bookingLight.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _summaryRow('Treatment', treatmentName),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'Cabang',
                    branch?['nama']?.toString() ?? 'Belum dipilih',
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'Dokter',
                    doc?['nama']?.toString() ?? 'Belum dipilih',
                  ),
                  const SizedBox(height: 12),
                  _summaryRow(
                    'Jadwal',
                    when == null
                        ? 'Belum dipilih'
                        : '${when!.day}/${when!.month}/${when!.year}'
                            ' • ${formatTime(when!)}',
                  ),
                  const SizedBox(height: 12),
                  _currencySelectorRow(),
                  if (selectedCurrency != 'IDR') ...[
                    const SizedBox(height: 10),
                    _summaryRow(
                      'Kurs Konversi',
                      CurrencyService.formatRateDescription(selectedCurrency),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Colors.white, height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total perawatan',
                              style: TextStyle(
                                color: bookingText,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            if (selectedCurrency != 'IDR') ...[
                              const SizedBox(height: 2),
                              Text(
                                'Dasar QRIS: Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')}',
                                style: const TextStyle(
                                  color: bookingMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              color: bookingPink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (selectedCurrency != 'IDR')
                            Text(
                              'Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')}',
                              style: const TextStyle(
                                color: bookingMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // TOMBOL KONFIRMASI
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: canSubmit ? save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: bookingPink,
                  disabledBackgroundColor: const Color(0xFFE5DCDD),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded),
                          SizedBox(width: 9),
                          Text(
                            'Konfirmasi Booking',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: bookingMuted,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Pastikan dokter dan jadwal sudah benar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bookingMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String number) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bookingLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: bookingPink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: bookingText,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              color: bookingMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: bookingText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _currencySelectorRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Mata uang',
            style: TextStyle(
              color: bookingMuted,
              fontSize: 12,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: supportedCurrencies.keys.map((curr) {
            final isSelected = curr == selectedCurrency;
            return ChoiceChip(
              label: Text(
                curr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : bookingText,
                ),
              ),
              selected: isSelected,
              selectedColor: bookingPink,
              backgroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: saving
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() {
                          selectedCurrency = curr;
                        });
                        CurrencyService.setCurrency(curr);
                      }
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: bookingLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.spa_rounded,
        color: bookingPink,
        size: 34,
      ),
    );
  }
}