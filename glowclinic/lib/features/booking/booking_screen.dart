import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/features/booking/doctor_schedule_service.dart';
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
  // Step 1: Cabang
  List<Map<String, dynamic>> branches = [];
  int? selectedBranchId;

  // Step 2: Treatment
  List<Map<String, dynamic>> treatments = [];
  late Map<String, dynamic> fallbackTreatment;
  int? selectedTreatmentId;

  // Step 3: Tanggal
  late DateTime selectedDate;

  // Step 4: Dokter
  List<Map<String, dynamic>> doctors = [];
  // Daftar dokter yang praktik pada tanggal/cabang terpilih sebelum filter jam.
  List<Map<String, dynamic>> allDoctorsForDate = [];
  int? selectedDoctorId;
  DoctorDailySchedule? doctorSchedule;

  // Step 5: Slot Waktu
  List<BookingSlot> slots = [];
  BookingSlot? selectedSlot;
  String selectedZone = 'WIB';

  // Loading & State Flags
  bool loadingBranches = true;
  bool loadingDoctors = false;
  bool loadingSlots = false;
  bool saving = false;

  String? branchError;
  String? doctorError;
  late String selectedCurrency;

  @override
  void initState() {
    super.initState();
    selectedCurrency = CurrencyService.activeCurrency.value;
    fallbackTreatment = Map<String, dynamic>.from(widget.t);
    selectedTreatmentId = (widget.t['id'] as num?)?.toInt();

    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);

    _initData();
  }

  Map<String, dynamic>? get currentBranch {
    if (selectedBranchId == null) return null;
    try {
      return branches.firstWhere(
        (b) => (b['id'] as num?)?.toInt() == selectedBranchId,
      );
    } catch (_) {
      return branches.isNotEmpty ? branches.first : null;
    }
  }

  Map<String, dynamic>? get currentDoctor {
    if (selectedDoctorId == null) return null;
    try {
      return doctors.firstWhere(
        (d) => (d['id'] as num?)?.toInt() == selectedDoctorId,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> get currentTreatment {
    if (selectedTreatmentId == null) return fallbackTreatment;
    try {
      return treatments.firstWhere(
        (t) => (t['id'] as num?)?.toInt() == selectedTreatmentId,
      );
    } catch (_) {
      return fallbackTreatment;
    }
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadBranches(),
      _loadTreatments(),
    ]);
  }

  Future<void> _loadTreatments() async {
    try {
      final res = await qry('SELECT * FROM treatments ORDER BY nama');
      if (!mounted) return;

      setState(() {
        treatments = List<Map<String, dynamic>>.from(res);
        if (selectedTreatmentId != null) {
          final exists = treatments.any(
            (t) => (t['id'] as num?)?.toInt() == selectedTreatmentId,
          );
          if (!exists && treatments.isNotEmpty) {
            // Cek kecocokan nama jika ID dari Supabase berbeda
            final nameMatch = treatments.where(
              (t) => '${t['nama']}'.toLowerCase() == '${fallbackTreatment['nama']}'.toLowerCase(),
            );
            if (nameMatch.isNotEmpty) {
              selectedTreatmentId = (nameMatch.first['id'] as num?)?.toInt();
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadBranches() async {
    setState(() {
      loadingBranches = true;
      branchError = null;
    });

    try {
      final result = await qry('SELECT * FROM branches ORDER BY id');
      if (!mounted) return;

      setState(() {
        branches = List<Map<String, dynamic>>.from(result);
        if (branches.isNotEmpty) {
          final isStillValid = branches.any(
            (b) => (b['id'] as num?)?.toInt() == selectedBranchId,
          );
          if (!isStillValid) {
            selectedBranchId = (branches.first['id'] as num?)?.toInt();
          }
        } else {
          selectedBranchId = null;
        }
        loadingBranches = false;
      });

      if (selectedBranchId != null) {
        await _loadDoctors();
      }
    } catch (e, st) {
      debugPrint('_loadBranches error: $e\n$st');
      if (!mounted) return;
      setState(() {
        loadingBranches = false;
        branchError = 'Gagal memuat daftar cabang: $e';
      });
    }
  }

  Future<void> _onBranchSelected(int? branchId) async {
    if (branchId == null || saving || branchId == selectedBranchId) return;

    setState(() {
      selectedBranchId = branchId;
      selectedDoctorId = null;
      doctorSchedule = null;
      slots = [];
      selectedSlot = null;
    });

    await _loadDoctors();
  }

  Future<void> _onTreatmentSelected(int? treatmentId) async {
    if (treatmentId == null || saving || treatmentId == selectedTreatmentId) return;

    setState(() {
      selectedTreatmentId = treatmentId;
      selectedSlot = null;
      doctors = List<Map<String, dynamic>>.from(allDoctorsForDate);
    });

    // Durasi treatment berubah -> hitung ulang slot waktu
    if (selectedDoctorId != null && selectedBranchId != null) {
      await _loadSlots();
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == selectedDate || saving) return;

    setState(() {
      selectedDate = normalized;
      selectedSlot = null;
    });

    // Tanggal berubah -> filter ulang dokter yang praktik pada tanggal tersebut
    await _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    final branchId = selectedBranchId;
    if (branchId == null) {
      setState(() {
        doctors = [];
        allDoctorsForDate = [];
        selectedDoctorId = null;
        doctorSchedule = null;
        slots = [];
        selectedSlot = null;
      });
      return;
    }

    setState(() {
      loadingDoctors = true;
      doctorError = null;
    });

    try {
      final result = await DoctorScheduleService.getDoctorsForBranch(
        branchId: branchId,
        date: selectedDate,
      );

      if (!mounted) return;

      setState(() {
        allDoctorsForDate = List<Map<String, dynamic>>.from(result);
        doctors = List<Map<String, dynamic>>.from(result);
        loadingDoctors = false;

        // Cek apakah dokter yang dipilih sebelumnya masih ada di daftar hari ini
        if (selectedDoctorId != null) {
          final stillAvailable = doctors.any(
            (d) => (d['id'] as num?)?.toInt() == selectedDoctorId,
          );
          if (!stillAvailable) {
            // Pilih dokter pertama yang tersedia pada hari tersebut jika ada
            selectedDoctorId = doctors.isNotEmpty
                ? (doctors.first['id'] as num?)?.toInt()
                : null;
            doctorSchedule = null;
            slots = [];
            selectedSlot = null;
          }
        } else if (doctors.isNotEmpty) {
          // Otomatis pilih dokter pertama agar jadwal langsung terlihat
          selectedDoctorId = (doctors.first['id'] as num?)?.toInt();
        }
      });

      if (selectedDoctorId != null) {
        await _loadSlots();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingDoctors = false;
        doctorError = 'Gagal memuat daftar dokter untuk cabang dan tanggal ini.';
      });
    }
  }

  Future<void> _onDoctorSelected(int? doctorId) async {
    if (doctorId == null || saving || doctorId == selectedDoctorId) return;

    setState(() {
      selectedDoctorId = doctorId;
      // Pertahankan jam yang dipilih; _loadSlots akan mengecek apakah
      // dokter baru juga masih tersedia pada jam yang sama.
    });

    await _loadSlots();
  }

  /// Setelah pasien memilih jam, tampilkan hanya dokter di cabang dan tanggal
  /// yang sama yang juga memiliki slot kosong pada jam tersebut.
  Future<void> _filterDoctorsForSelectedTime(BookingSlot slot) async {
    final branchId = selectedBranchId;
    if (branchId == null || allDoctorsForDate.isEmpty) return;

    final requestedDate = selectedDate;
    final requestedTreatmentId = selectedTreatmentId;
    final duration = (currentTreatment['durasi_menit'] as num?)?.toInt() ?? 60;
    final candidates = List<Map<String, dynamic>>.from(allDoctorsForDate);
    final availableDoctors = <Map<String, dynamic>>[];

    for (final doctor in candidates) {
      final doctorId = (doctor['id'] as num?)?.toInt();
      if (doctorId == null) continue;

      try {
        final candidateSlots = await DoctorScheduleService.calculateAvailableSlots(
          doctorId: doctorId,
          branchId: branchId,
          date: requestedDate,
          treatmentDurationMinutes: duration,
          selectedZone: selectedZone,
        );
        final isAvailable = candidateSlots.any(
          (candidate) =>
              candidate.timeUtc == slot.timeUtc && candidate.isAvailable,
        );
        if (isAvailable) availableDoctors.add(doctor);
      } catch (e) {
        debugPrint('[BOOKING] Gagal memeriksa slot dokter $doctorId: $e');
      }
    }

    if (!mounted ||
        selectedBranchId != branchId ||
        selectedDate != requestedDate ||
        selectedSlot?.timeUtc != slot.timeUtc ||
        selectedTreatmentId != requestedTreatmentId) {
      return;
    }

    setState(() {
      doctors = availableDoctors;
      if (!doctors.any((d) => (d['id'] as num?)?.toInt() == selectedDoctorId)) {
        selectedDoctorId = doctors.isNotEmpty
            ? (doctors.first['id'] as num?)?.toInt()
            : null;
        doctorSchedule = null;
        slots = [];
      }
    });

    // Jika dokter aktif berubah, muat ulang slotnya sambil mempertahankan
    // pilihan jam bila jam tersebut tetap tersedia.
    if (selectedDoctorId != null &&
        !slots.any((candidate) =>
            candidate.timeUtc == slot.timeUtc && candidate.isAvailable)) {
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    final doctorId = selectedDoctorId;
    final branchId = selectedBranchId;

    if (doctorId == null || branchId == null) {
      setState(() {
        slots = [];
        selectedSlot = null;
        doctorSchedule = null;
      });
      return;
    }

    setState(() {
      loadingSlots = true;
    });

    try {
      final duration = (currentTreatment['durasi_menit'] as num?)?.toInt() ?? 60;

      final schedule = await DoctorScheduleService.getSchedule(
        doctorId: doctorId,
        branchId: branchId,
        date: selectedDate,
      );

      final calculatedSlots = await DoctorScheduleService.calculateAvailableSlots(
        doctorId: doctorId,
        branchId: branchId,
        date: selectedDate,
        treatmentDurationMinutes: duration,
        selectedZone: selectedZone,
      );

      if (!mounted) return;

      setState(() {
        doctorSchedule = schedule;
        slots = calculatedSlots;
        loadingSlots = false;

        // Pertahankan slot jika masih tersedia
        if (selectedSlot != null) {
          final matches = slots.where(
            (s) => s.timeUtc == selectedSlot!.timeUtc && s.isAvailable,
          );
          selectedSlot = matches.isNotEmpty ? matches.first : null;
        }
        if (selectedSlot == null) {
          doctors = List<Map<String, dynamic>>.from(allDoctorsForDate);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingSlots = false;
        slots = [];
        selectedSlot = null;
      });
    }
  }

  Future<void> _pickDateModal() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 90));

    DateTime initial = selectedDate;
    if (initial.isBefore(today)) initial = today;
    if (initial.isAfter(maxDate)) initial = maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: maxDate,
      helpText: 'PILIH TANGGAL PERAWATAN',
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

    if (picked != null && mounted) {
      await _onDateSelected(picked);
    }
  }

  Future<void> _saveBooking() async {
    final branch = currentBranch;
    final doctor = currentDoctor;
    final treatment = currentTreatment;

    if (saving ||
        branch == null ||
        doctor == null ||
        selectedSlot == null ||
        !selectedSlot!.isAvailable) {
      return;
    }

    setState(() {
      saving = true;
    });

    final duration = (treatment['durasi_menit'] as num?)?.toInt() ?? 60;
    final doctorId = (doctor['id'] as num?)?.toInt() ?? 0;
    final branchId = (branch['id'] as num?)?.toInt() ?? 0;
    final startUtc = selectedSlot!.timeUtc;
    final effectiveUserId = myId ?? 1;

    // VALIDASI ULANG KONFLIK LANGSUNG KE DATABASE SEBELUM DISIMPAN
    final isStillFree = await DoctorScheduleService.isSlotAvailable(
      doctorId: doctorId,
      branchId: branchId,
      startUtc: startUtc,
      durationMinutes: duration,
    );

    if (!isStillFree) {
      if (!mounted) return;
      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maaf, slot waktu ini baru saja dipesan oleh pengguna lain. Silakan pilih slot lain.',
          ),
          backgroundColor: bookingDark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh slots agar status ter-update
      await _loadSlots();
      return;
    }

    bool bookingSaved = false;
    try {
      final priceIdr = (treatment['harga_idr'] as num?)?.toInt() ?? 0;
      final rate = CurrencyService.getRate(selectedCurrency);
      final totalBayar = CurrencyService.convertFromIdr(
        priceIdr,
        selectedCurrency,
        customRate: rate,
      );

      final bookingId = await db.insert('bookings', {
        'user_id': effectiveUserId,
        'doctor_id': doctorId,
        'branch_id': branchId,
        'treatment_id': treatment['id'],
        'treatment_nama': treatment['nama']?.toString(),
        'waktu_utc': startUtc.toIso8601String(),
        'durasi_menit': duration,
        'status': 'pending',
        'status_bayar': 'belum_bayar',
        'total_idr': priceIdr,
        'mata_uang': selectedCurrency,
        'kurs': rate,
        'total_bayar': totalBayar,
      });

      bookingSaved = true;
      bookingRefresh.value++;

      try {
        final me = await qry('SELECT nama FROM users WHERE id = ?', [effectiveUserId]);
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
          isi: '$who memesan ${treatment['nama']} seharga $priceSummary pada '
              '${fmtDateTime(startUtc.toIso8601String())}. Segera Acc atau Tolak.',
          tipe: 'booking',
          bookingId: bookingId,
        );
      } catch (_) {}

      try {
        await Chain.add(
          'booking:$bookingId:$effectiveUserId:$selectedCurrency:$totalBayar:$priceIdr:${startUtc.toIso8601String()}',
        );
      } catch (_) {}

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(
          context,
          'Booking berhasil dikirim dan menunggu konfirmasi.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      final message = bookingSaved
          ? 'Booking tersimpan, tetapi pencatatan blockchain gagal.'
          : 'Booking gagal disimpan. Silakan coba lagi.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bookingDark,
          behavior: SnackBarBehavior.floating,
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

  String _formatDateDisplay(DateTime date) {
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

    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDayShort(DateTime date) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final treatment = currentTreatment;
    final doctor = currentDoctor;
    final branch = currentBranch;

    final treatmentName = treatment['nama']?.toString() ?? 'Treatment';
    final category = treatment['kategori']?.toString() ?? 'Perawatan';
    final duration = (treatment['durasi_menit'] as num?)?.toInt() ?? 60;
    final priceIdr = (treatment['harga_idr'] as num?)?.toInt() ?? 0;
    final totalBayar = CurrencyService.convertFromIdr(priceIdr, selectedCurrency);
    final formattedPrice = CurrencyService.formatMoney(totalBayar, selectedCurrency);
    final photo = treatment['foto_url']?.toString().trim() ?? '';

    final canSubmit = branch != null &&
        doctor != null &&
        selectedSlot != null &&
        selectedSlot!.isAvailable &&
        !saving &&
        !loadingDoctors &&
        !loadingSlots;

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
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            // HEADER HERO
            _buildHeroBanner(),

            const SizedBox(height: 24),

            // STEP 01: PILIH CABANG
            _sectionTitle('Pilih Cabang', '01'),
            const SizedBox(height: 12),
            _buildBranchSection(),

            const SizedBox(height: 24),

            // STEP 02: TREATMENT
            _sectionTitle('Treatment Dipilih', '02'),
            const SizedBox(height: 12),
            _buildTreatmentCard(
              category: category,
              name: treatmentName,
              duration: duration,
              formattedPrice: formattedPrice,
              priceIdr: priceIdr,
              photo: photo,
            ),

            const SizedBox(height: 24),

            // STEP 03: PILIH TANGGAL
            _sectionTitle('Pilih Tanggal', '03'),
            const SizedBox(height: 12),
            _buildDateSelector(),

            const SizedBox(height: 24),

            // STEP 04: PILIH DOKTER YANG TERSEDIA
            _sectionTitle('Dokter yang Tersedia', '04'),
            const SizedBox(height: 12),
            _buildDoctorSelector(),

            const SizedBox(height: 24),

            // STEP 05: PILIH SLOT WAKTU KOSONG
            _sectionTitle('Pilih Slot Waktu', '05'),
            const SizedBox(height: 12),
            _buildTimeSlotSection(),

            const SizedBox(height: 26),

            // STEP 06: RINGKASAN BOOKING
            _sectionTitle('Ringkasan Booking', '06'),
            const SizedBox(height: 12),
            _buildSummaryCard(
              treatmentName: treatmentName,
              duration: duration,
              priceIdr: priceIdr,
              formattedPrice: formattedPrice,
            ),

            const SizedBox(height: 22),

            // TOMBOL KONFIRMASI
            _buildSubmitButton(canSubmit),

            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: bookingMuted,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Jadwal terverifikasi langsung secara real-time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bookingMuted,
                      fontSize: 11,
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

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bookingPink, bookingDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bookingPink.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reservasi Treatment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pilih cabang, dokter yang bertugas, dan slot waktu yang tersedia.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSection() {
    if (loadingBranches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: bookingPink),
        ),
      );
    }

    if (branchError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                branchError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _loadBranches,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final branch = currentBranch;
    final validBranchId = branches.any(
      (b) => (b['id'] as num?)?.toInt() == selectedBranchId,
    )
        ? selectedBranchId
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bookingLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey(validBranchId),
            initialValue: validBranchId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih Cabang',
              labelStyle: const TextStyle(color: bookingMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.location_on, color: bookingPink),
              filled: true,
              fillColor: bookingBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final item in branches)
                DropdownMenuItem<int>(
                  value: (item['id'] as num?)?.toInt(),
                  child: Text(
                    item['nama']?.toString() ?? 'Cabang',
                    style: const TextStyle(
                      color: bookingText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: saving ? null : _onBranchSelected,
          ),
          if (branch != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bookingLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: bookingPink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${branch['alamat'] ?? 'Alamat belum tersedia'}'
                      '\nJam Buka: ${branch['jam_buka'] ?? '09:00 - 18:00'}',
                      style: const TextStyle(
                        color: bookingMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTreatmentCard({
    required String category,
    required String name,
    required int duration,
    required String formattedPrice,
    required int priceIdr,
    required String photo,
  }) {
    final validTreatmentId = treatments.any(
      (t) => (t['id'] as num?)?.toInt() == selectedTreatmentId,
    )
        ? selectedTreatmentId
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: photo.startsWith('http')
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
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
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bookingLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: bookingPink,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: bookingText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: bookingMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$duration menit',
                          style: const TextStyle(
                            color: bookingMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formattedPrice,
                          style: const TextStyle(
                            color: bookingPink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (treatments.length > 1 && validTreatmentId != null) ...[
            const SizedBox(height: 12),
            const Divider(color: bookingLight, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ganti Treatment:',
                  style: TextStyle(
                    color: bookingMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: validTreatmentId,
                    isDense: true,
                    style: const TextStyle(
                      color: bookingPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: bookingPink,
                      size: 20,
                    ),
                    items: [
                      for (final t in treatments)
                        DropdownMenuItem<int>(
                          value: (t['id'] as num?)?.toInt(),
                          child: Text(t['nama']?.toString() ?? ''),
                        ),
                    ],
                    onChanged: saving ? null : _onTreatmentSelected,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Daftar 7 hari ke depan
    final dayList = List.generate(7, (i) => today.add(Duration(days: i)));

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateDisplay(selectedDate),
                style: const TextStyle(
                  color: bookingText,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              InkWell(
                onTap: saving ? null : _pickDateModal,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bookingLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, color: bookingPink, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Pilih Lainnya',
                        style: TextStyle(
                          color: bookingPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dayList.map((d) {
                final isSelected = d.year == selectedDate.year &&
                    d.month == selectedDate.month &&
                    d.day == selectedDate.day;
                final isToday = d == today;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: saving ? null : () => _onDateSelected(d),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 54,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? bookingPink : bookingBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? bookingPink : bookingLight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isToday ? 'Hari Ini' : _formatDayShort(d),
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : bookingMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : bookingText,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorSelector() {
    if (loadingDoctors) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: bookingPink),
        ),
      );
    }

    if (doctorError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          doctorError!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      );
    }

    if (doctors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bookingLight),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.event_busy_rounded,
              color: bookingMuted,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              'Tidak ada dokter yang berpraktik di ${currentBranch?['nama'] ?? 'cabang ini'} '
              'pada ${_formatDateDisplay(selectedDate)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: bookingText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Silakan pilih tanggal lain atau beralih ke cabang lain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: bookingMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final validDoctorId = doctors.any(
      (d) => (d['id'] as num?)?.toInt() == selectedDoctorId,
    )
        ? selectedDoctorId
        : null;

    final doctor = currentDoctor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bookingLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('${selectedDate.millisecondsSinceEpoch}_$validDoctorId'),
            initialValue: validDoctorId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih Dokter',
              labelStyle: const TextStyle(color: bookingMuted, fontSize: 13),
              prefixIcon: const Icon(
                Icons.medical_services_outlined,
                color: bookingPink,
              ),
              filled: true,
              fillColor: bookingBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final d in doctors)
                DropdownMenuItem<int>(
                  value: (d['id'] as num?)?.toInt(),
                  child: Text(
                    '${d['nama'] ?? 'Tanpa Nama'} (${d['spesialisasi'] ?? '-'})',
                    style: const TextStyle(
                      color: bookingText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: saving ? null : _onDoctorSelected,
          ),
          if (doctor != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bookingLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: bookingPink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${doctor['pendidikan'] ?? 'Dokter Spesialis'} • Pengalaman ${doctor['pengalaman_tahun'] ?? 0} tahun',
                          style: const TextStyle(
                            color: bookingText,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jadwal: ${doctor['jadwal_praktik'] ?? '-'}',
                          style: const TextStyle(
                            color: bookingMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlotSection() {
    if (selectedDoctorId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bookingLight),
        ),
        child: const Center(
          child: Text(
            'Silakan pilih dokter terlebih dahulu untuk melihat jadwal slot waktu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: bookingMuted, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bookingLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TIMEZONE SELECTOR
          Row(
            children: [
              const Icon(
                Icons.language_rounded,
                color: bookingPink,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Zona Waktu:',
                style: TextStyle(
                  color: bookingMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedZone,
                    isDense: true,
                    style: const TextStyle(
                      color: bookingPink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'WIB', child: Text('WIB (UTC+7)')),
                      DropdownMenuItem(value: 'WITA', child: Text('WITA (UTC+8)')),
                      DropdownMenuItem(value: 'WIT', child: Text('WIT (UTC+9)')),
                      DropdownMenuItem(value: 'London', child: Text('London (UK)')),
                    ],
                    onChanged: saving
                        ? null
                        : (val) {
                            if (val != null && val != selectedZone) {
                              setState(() {
                                selectedZone = val;
                              });
                              _loadSlots();
                            }
                          },
                  ),
                ),
              ),
            ],
          ),

          if (doctorSchedule != null) ...[
            const SizedBox(height: 8),
            Text(
              'Jam Praktik Hari Ini: ${doctorSchedule!.formattedHours} WIB',
              style: const TextStyle(
                color: bookingMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: bookingLight, height: 1),
          ),

          if (loadingSlots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: bookingPink),
              ),
            )
          else if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    color: bookingMuted,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tidak ada jadwal praktik dokter yang tersedia pada tanggal ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bookingMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Status Legend
            Row(
              children: [
                _buildLegendItem(
                  color: bookingPink,
                  label: 'Dipilih',
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
                  color: Colors.white,
                  borderColor: bookingLight,
                  label: 'Tersedia',
                ),
                const SizedBox(width: 14),
                _buildLegendItem(
                  color: const Color(0xFFEBE6E8),
                  label: 'Penuh/Lewat',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Slot Chips Grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: slots.map((slot) {
                final isSelected = selectedSlot != null &&
                    selectedSlot!.timeUtc == slot.timeUtc;
                final isAvailable = slot.isAvailable;

                Color bgColor;
                Color textColor;
                Color borderColor;

                if (isSelected) {
                  bgColor = bookingPink;
                  textColor = Colors.white;
                  borderColor = bookingPink;
                } else if (isAvailable) {
                  bgColor = Colors.white;
                  textColor = bookingText;
                  borderColor = bookingLight;
                } else {
                  bgColor = const Color(0xFFF4EEF0);
                  textColor = const Color(0xFFAFA3A6);
                  borderColor = const Color(0xFFE6DEE0);
                }

                return InkWell(
                  onTap: (!isAvailable || saving)
                      ? null
                      : () async {
                          setState(() {
                            selectedSlot = slot;
                          });
                          await _filterDoctorsForSelectedTime(slot);
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 95,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          slot.timeLabel,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          slot.statusLabel,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : isAvailable
                                    ? Colors.green.shade700
                                    : const Color(0xFFAFA3A6),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            if (slots.every((s) => !s.isAvailable)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Semua jadwal dokter sudah penuh untuk tanggal ini. Silakan pilih tanggal atau dokter lain.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    Color? borderColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: borderColor ?? color,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: bookingMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String treatmentName,
    required int duration,
    required int priceIdr,
    required String formattedPrice,
  }) {
    String slotDisplay = 'Belum dipilih';
    String estimatedEnd = '-';

    if (selectedSlot != null) {
      final start = selectedSlot!.time;
      final end = start.add(Duration(minutes: duration));
      final sH = start.hour.toString().padLeft(2, '0');
      final sM = start.minute.toString().padLeft(2, '0');
      final eH = end.hour.toString().padLeft(2, '0');
      final eM = end.minute.toString().padLeft(2, '0');

      slotDisplay = '$sH:$sM $selectedZone';
      estimatedEnd = '$eH:$eM $selectedZone';
    }

    final branch = currentBranch;
    final doctor = currentDoctor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bookingLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bookingLight),
      ),
      child: Column(
        children: [
          _summaryRow('Cabang', branch?['nama']?.toString() ?? 'Belum dipilih'),
          const SizedBox(height: 10),
          _summaryRow('Treatment', treatmentName),
          const SizedBox(height: 10),
          _summaryRow('Durasi', '$duration menit'),
          const SizedBox(height: 10),
          _summaryRow('Dokter', doctor?['nama']?.toString() ?? 'Belum dipilih'),
          const SizedBox(height: 10),
          _summaryRow('Tanggal', _formatDateDisplay(selectedDate)),
          const SizedBox(height: 10),
          _summaryRow('Jam Mulai', slotDisplay),
          const SizedBox(height: 10),
          _summaryRow('Perkiraan Selesai', estimatedEnd),
          const SizedBox(height: 10),
          _currencySelectorRow(),
          if (selectedCurrency != 'IDR') ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Kurs Konversi',
              CurrencyService.formatRateDescription(selectedCurrency),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Biaya',
                    style: TextStyle(
                      color: bookingText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  if (selectedCurrency != 'IDR')
                    Text(
                      'Rp ${CurrencyService.formatAmount(priceIdr, 'IDR')}',
                      style: const TextStyle(
                        color: bookingMuted,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
              Text(
                formattedPrice,
                style: const TextStyle(
                  color: bookingPink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool canSubmit) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: canSubmit ? _saveBooking : null,
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
                  SizedBox(width: 8),
                  Text(
                    'Konfirmasi Booking',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
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
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bookingLight,
            borderRadius: BorderRadius.circular(8),
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
            fontSize: 15.5,
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
        const SizedBox(width: 8),
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
                  fontSize: 10.5,
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
        size: 32,
      ),
    );
  }
}