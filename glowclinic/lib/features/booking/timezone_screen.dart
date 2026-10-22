import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowclinic/features/booking/zones.dart';

// ============================================================
// Warna konsisten dengan tema GlowClinic
// ============================================================
const Color _primary = Color(0xFF87364B);
const Color _background = Color(0xFFFFF7F9);
const Color _surface = Colors.white;
const Color _text = Color(0xFF3D2532);
const Color _muted = Color(0xFFB08C99);
const Color _light = Color(0xFFFFE1EA);
const Color _accent = Color(0xFFD85F89);

/// Layar Konversi Waktu — memungkinkan pengguna memilih
/// zona waktu asal dan tujuan secara bebas dari 4 pilihan:
/// WIB, WITA, WIT, dan London.
class TimeZoneConversionScreen extends StatefulWidget {
  const TimeZoneConversionScreen({super.key});

  @override
  State<TimeZoneConversionScreen> createState() => _TZCS();
}

class _TZCS extends State<TimeZoneConversionScreen> {
  // ── State zona waktu ─────────────────────────────────────
  String _fromZone = 'WIB';
  String _toZone = 'London';

  // ── State input tanggal & waktu ──────────────────────────
  DateTime _selectedDate = DateTime.now();
  final _hourCtrl = TextEditingController(text: '10');
  final _minCtrl = TextEditingController(text: '00');

  // ── State hasil konversi ──────────────────────────────────
  TimeConversionResult? _result;
  String? _errorMsg;

  final List<String> _zoneKeys = supportedTimeZones.keys.toList();

  @override
  void initState() {
    super.initState();
    TimeZoneService.ensureInitialized();
    // Langsung hitung saat layar dibuka
    _convert();
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  // ── Konversi ─────────────────────────────────────────────
  void _convert() {
    final hourStr = _hourCtrl.text.trim();
    final minStr = _minCtrl.text.trim();

    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minStr);

    if (hour == null || hour < 0 || hour > 23) {
      setState(() {
        _result = null;
        _errorMsg = 'Jam tidak valid. Masukkan angka antara 00–23.';
      });
      return;
    }

    if (minute == null || minute < 0 || minute > 59) {
      setState(() {
        _result = null;
        _errorMsg = 'Menit tidak valid. Masukkan angka antara 00–59.';
      });
      return;
    }

    try {
      final result = TimeZoneService.convert(
        fromZone: _fromZone,
        toZone: _toZone,
        date: _selectedDate,
        hour: hour,
        minute: minute,
      );

      setState(() {
        _result = result;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() {
        _result = null;
        _errorMsg = 'Terjadi kesalahan: $e';
      });
    }
  }

  // ── Tukar zona asal & tujuan ──────────────────────────────
  void _swap() {
    setState(() {
      final temp = _fromZone;
      _fromZone = _toZone;
      _toZone = temp;
    });
    _convert();
  }

  // ── Pilih tanggal ─────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(

      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _text,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _convert();
    }
  }

  // ── Dropdown zona waktu ───────────────────────────────────
  Widget _zoneDropdown({
    required String value,
    required String label,
    required ValueChanged<String?> onChanged,
    required String heroTag,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _light, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
              onChanged: onChanged,
              items: _zoneKeys.map((key) {
                final info = supportedTimeZones[key]!;
                return DropdownMenuItem<String>(
                  value: key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      Text(
                        info.defaultOffsetLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (supportedTimeZones[value] != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              supportedTimeZones[value]!.locationName,
              style: const TextStyle(
                fontSize: 10,
                color: _muted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Kartu hasil konversi ──────────────────────────────────
  Widget _resultCard() {
    if (_errorMsg != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMsg!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (_result == null) {
      return const SizedBox.shrink();
    }

    final r = _result!;
    final sourceTimeStr =
        '${r.fromHour.toString().padLeft(2, '0')}:${r.fromMinute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primary.withValues(alpha: 0.92),
            _accent.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header hasil ──
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Hasil Konversi',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Waktu asal ──
          _resultRow(
            icon: Icons.schedule_rounded,
            label: 'Waktu Asal (${ r.fromZone})',
            value: '$sourceTimeStr  •  ${r.formattedSourceDate}',
          ),
          const SizedBox(height: 10),

          // ── Panah konversi ──
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Waktu hasil ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.toZone,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      r.formattedTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.toZone,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // ── Pergantian tanggal ──
                if (r.isDateChanged) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.amber,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r.formattedTargetDate,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (r.dateChangeNotice != null) ...[
                          const SizedBox(width: 5),
                          Text(
                            '(${r.dateChangeNotice})',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Selisih zona waktu ──
          _resultRow(
            icon: Icons.compare_arrows_rounded,
            label: 'Selisih',
            value: r.differenceDescription,
          ),

          // ── DST London ──
          if (r.londonDstStatus != null) ...[
            const SizedBox(height: 8),
            _resultRow(
              icon: Icons.wb_sunny_rounded,
              label: 'DST',
              value: r.londonDstStatus!,
              valueColor: Colors.amber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white60, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Konversi Waktu',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        actions: [
          // Tombol Sekarang – langsung isi waktu saat ini
          TextButton.icon(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _selectedDate = now;
                _hourCtrl.text = now.hour.toString().padLeft(2, '0');
                _minCtrl.text = now.minute.toString().padLeft(2, '0');
              });
              _convert();
            },
            icon: const Icon(Icons.access_time_rounded, size: 16, color: _primary),
            label: const Text(
              'Sekarang',
              style: TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─────────────────────────────────────────────
            // SECTION 1 — ZONA WAKTU ASAL
            // ─────────────────────────────────────────────
            _sectionHeader('01', 'Zona Waktu Asal'),
            const SizedBox(height: 10),

            _zoneDropdown(
              value: _fromZone,
              label: 'DARI',
              heroTag: 'from',
              onChanged: (v) {
                if (v != null) {
                  setState(() => _fromZone = v);
                  _convert();
                }
              },
            ),

            const SizedBox(height: 20),

            // ─────────────────────────────────────────────
            // SECTION 2 — INPUT TANGGAL & JAM
            // ─────────────────────────────────────────────
            _sectionHeader('02', 'Tanggal & Waktu'),
            const SizedBox(height: 10),

            // Pilih tanggal
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _light, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: _primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        TimeZoneService.formatIndonesianDate(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded, color: _muted, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Input jam dan menit
            Row(
              children: [
                Expanded(
                  child: _timeInputField(
                    controller: _hourCtrl,
                    label: 'Jam (00–23)',
                    hint: 'HH',
                    maxVal: 23,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: _timeInputField(
                    controller: _minCtrl,
                    label: 'Menit (00–59)',
                    hint: 'MM',
                    maxVal: 59,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // SECTION 3 — ZONA WAKTU TUJUAN + TOMBOL TUKAR
            // ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _sectionHeader('03', 'Zona Waktu Tujuan')),
                // Tombol tukar
                Container(
                  decoration: BoxDecoration(
                    color: _light,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    tooltip: 'Tukar zona waktu asal & tujuan',
                    icon: const Icon(Icons.swap_vert_rounded, color: _primary, size: 22),
                    onPressed: _swap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _zoneDropdown(
              value: _toZone,
              label: 'KE',
              heroTag: 'to',
              onChanged: (v) {
                if (v != null) {
                  setState(() => _toZone = v);
                  _convert();
                }
              },
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // TOMBOL KONVERSI
            // ─────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _convert,
                icon: const Icon(Icons.autorenew_rounded, size: 20),
                label: const Text('Konversi'),
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // SECTION 4 — HASIL KONVERSI
            // ─────────────────────────────────────────────
            _sectionHeader('04', 'Hasil Konversi'),
            const SizedBox(height: 10),

            _resultCard(),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // SECTION 5 — TABEL SEMUA ZONA WAKTU
            // ─────────────────────────────────────────────
            _sectionHeader('05', 'Semua Zona Waktu'),
            const SizedBox(height: 10),
            _allZonesTable(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String num, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
      ],
    );
  }

  Widget _timeInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxVal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
            _RangeInputFormatter(0, maxVal),
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _muted, fontSize: 22),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _light, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
          onChanged: (_) => _convert(),
        ),
      ],
    );
  }

  Widget _allZonesTable() {
    final hourStr = _hourCtrl.text.trim();
    final minStr = _minCtrl.text.trim();
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minStr);

    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return const SizedBox.shrink();
    }

    final allResults = TimeZoneService.convertToAllZones(
      fromZone: _fromZone,
      date: _selectedDate,
      hour: hour,
      minute: minute,
    );

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _light, width: 1.5),
      ),
      child: Column(
        children: allResults.entries.map((entry) {
          final zoneKey = entry.key;
          final r = entry.value;
          final isSource = zoneKey == _fromZone;
          final isTarget = zoneKey == _toZone;

          return Container(
            decoration: BoxDecoration(
              color: isTarget
                  ? _primary.withValues(alpha: 0.06)
                  : isSource
                  ? _light.withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isTarget ? _primary : isSource ? _light : _light.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  zoneKey,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isTarget ? Colors.white : _primary,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    r.formattedTime,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isTarget ? _primary : _text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    zoneKey,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                supportedTimeZones[zoneKey]!.locationName +
                    (r.isDateChanged ? '  •  ${r.formattedTargetDate}' : ''),
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r.isDateChanged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.dayDifference > 0
                            ? '+${r.dayDifference}d'
                            : '${r.dayDifference}d',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  if (isSource) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _light,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Asal',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                  if (isTarget) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Tujuan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Input formatter untuk memastikan nilai jam/menit dalam rentang valid
class _RangeInputFormatter extends TextInputFormatter {
  final int min;
  final int max;

  _RangeInputFormatter(this.min, this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    if (parsed < min || parsed > max) return oldValue;
    return newValue;
  }
}
