import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/notif.dart';

// Definisi warna konsisten tema GlowClinic
const Color _primary = Color(0xFF87364B);
const Color _primaryLight = Color(0xFFE9C5D0);
const Color _primarySoft = Color(0xFFFBF4F6);
const Color _textDark = Color(0xFF2C1820);

/// Helper format tanggal ke format Indonesia yang mudah dibaca
String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw);
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return raw;
  }
}

/// Helper format tanggal dan jam
String _fmtTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${_fmtDate(raw)} $h:$m';
  } catch (_) {
    return raw;
  }
}

/// Backwards compatibility untuk pemanggil lama yang memanggil PhotoScreen(booking)
class PhotoScreen extends StatelessWidget {
  final Map b;

  const PhotoScreen(this.b, {super.key});

  @override
  Widget build(BuildContext context) {
    return SkinJournalScreen(booking: Map<String, dynamic>.from(b));
  }
}

// ============================================================================
// 1. HALAMAN DAFTAR RIWAYAT JURNAL KULIT (SkinJournalScreen)
// ============================================================================

class SkinJournalScreen extends StatefulWidget {
  final Map<String, dynamic>? booking;

  const SkinJournalScreen({super.key, this.booking});

  @override
  State<SkinJournalScreen> createState() => _SkinJournalScreenState();
}

class _SkinJournalScreenState extends State<SkinJournalScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _journals = [];
  bool _filterOnlyCurrentBooking = false;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  int? get _currentUserId => myId;

  int? get _bookingId => widget.booking?['id'] as int?;

  String? get _treatmentNama =>
      (widget.booking?['t_nama'] ?? widget.booking?['treatment_nama'])?.toString();

  String? get _doctorNama =>
      (widget.booking?['d_nama'] ?? widget.booking?['doctor_nama'])?.toString();

  Future<void> _loadJournals() async {
    final uid = _currentUserId;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Pengguna belum terautentikasi.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await db.rawQuery('''
        SELECT 
          j.*,
          COALESCE(b.treatment_nama, t.nama) AS booking_treatment_nama,
          d.nama AS doctor_nama,
          b.waktu_utc AS booking_waktu_utc,
          b.status AS booking_status,
          b.catatan_dokter AS booking_catatan_dokter
        FROM skin_journals j
        LEFT JOIN bookings b ON b.id = j.booking_id
        LEFT JOIN treatments t ON t.id = b.treatment_id
        LEFT JOIN doctors d ON d.id = b.doctor_id
        WHERE j.user_id = ?
        ORDER BY j.tanggal DESC, j.id DESC
      ''', [uid]);

      if (!mounted) return;

      setState(() {
        _journals = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat riwayat jurnal kulit: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteJournal(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Jurnal Kulit?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Catatan jurnal dan riwayat foto pada entri ini akan dihapus secara permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final count = await db.delete(
        'skin_journals',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, _currentUserId],
      );

      if (!mounted) return;

      if (count > 0) {
        snack(context, 'Jurnal kulit berhasil dihapus');
        _loadJournals();
      } else {
        snack(context, 'Jurnal tidak ditemukan atau tidak memiliki izin');
      }
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Gagal menghapus jurnal: $e');
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existingJournal}) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SkinJournalFormScreen(
          initialBookingId: _bookingId,
          treatmentNama: _treatmentNama,
          doctorNama: _doctorNama,
          existingJournal: existingJournal,
        ),
      ),
    );

    if (refreshed == true && mounted) {
      _loadJournals();
    }
  }

  Color _badgeColor(String? kondisi) {
    switch (kondisi?.toLowerCase()) {
      case 'normal':
        return Colors.green.shade600;
      case 'kering':
        return Colors.blue.shade600;
      case 'berminyak':
        return Colors.orange.shade700;
      case 'kombinasi':
        return Colors.teal.shade700;
      case 'sensitif':
        return Colors.red.shade600;
      default:
        return _primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterOnlyCurrentBooking && _bookingId != null
        ? _journals.where((j) => j['booking_id'] == _bookingId).toList()
        : _journals;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Jurnal Kulit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text(
          'Tulis Jurnal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openForm(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadJournals,
        color: _primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Banner konteks booking bila dibuka dari card booking
            if (widget.booking != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primaryLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: _primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _treatmentNama ?? 'Perawatan Kulit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_doctorNama != null && _doctorNama!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Dokter: $_doctorNama',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.booking?['waktu_utc'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jadwal: ${_fmtTimestamp(widget.booking?['waktu_utc']?.toString())}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.booking?['catatan_dokter'] != null &&
                        widget.booking!['catatan_dokter'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _primaryLight.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_outlined, color: _primary, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Catatan Dokter: ${widget.booking!['catatan_dokter']}',
                                style: const TextStyle(fontSize: 12, color: _textDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Filter toggle jika ada booking id
            if (_bookingId != null && _journals.isNotEmpty) ...[
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua Riwayat Jurnal'),
                    selected: !_filterOnlyCurrentBooking,
                    selectedColor: _primaryLight,
                    onSelected: (val) {
                      setState(() => _filterOnlyCurrentBooking = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Treatment Ini Saja'),
                    selected: _filterOnlyCurrentBooking,
                    selectedColor: _primaryLight,
                    onSelected: (val) {
                      setState(() => _filterOnlyCurrentBooking = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Konten: Loading / Error / Empty / List
            if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: _primary),
                ),
              ),
            ] else if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primary),
                      onPressed: _loadJournals,
                      child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ] else if (filtered.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: _primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada catatan jurnal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _filterOnlyCurrentBooking
                          ? 'Belum ada jurnal khusus untuk treatment ini. Tekan tombol di bawah untuk mencatat kondisi kulit pertamamu!'
                          : 'Catat perkembangan kondisi kulit, keluhan, produk yang dipakai, serta foto kulitmu setelah perawatan agar mudah dipantau.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tulis Jurnal Baru'),
                      onPressed: () => _openForm(),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Daftar kartu riwayat jurnal
              ...filtered.map((item) {
                final condition = item['kondisi_kulit']?.toString() ?? 'Normal';
                final bColor = _badgeColor(condition);
                final photoPath = item['photo_path']?.toString();
                final bool hasPhoto = photoPath != null &&
                    photoPath.isNotEmpty &&
                    File(photoPath).existsSync();

                final treatmentLabel = (item['booking_treatment_nama'] ?? _treatmentNama)?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1.5,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkinJournalDetailScreen(
                            journal: item,
                            treatmentNama: treatmentLabel,
                            doctorNama: (item['doctor_nama'] ?? _doctorNama)?.toString(),
                            onDelete: () => _deleteJournal(item['id'] as int),
                            onEdit: () => _openForm(existingJournal: item),
                          ),
                        ),
                      ).then((_) => _loadJournals());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Card: Tanggal dan Badge Kondisi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 15, color: _primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _fmtDate(item['tanggal']?.toString()),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: _textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: bColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  condition,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: bColor,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (treatmentLabel != null && treatmentLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.spa_outlined, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Treatment: $treatmentLabel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Divider(height: 20),

                          // Foto (bila ada) dan Cuplikan Catatan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasPhoto) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(photoPath),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item['keluhan'] != null &&
                                        item['keluhan'].toString().trim().isNotEmpty) ...[
                                      Text(
                                        'Keluhan: ${item['keluhan']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (item['catatan'] != null &&
                                        item['catatan'].toString().trim().isNotEmpty) ...[
                                      Text(
                                        '${item['catatan']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade800,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (item['produk'] != null &&
                                        item['produk'].toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.sanitizer_outlined, size: 13, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Produk: ${item['produk']}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Aksi cepat: Edit & Hapus
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: _primary,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                onPressed: () => _openForm(existingJournal: item),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.delete_outline, size: 16),
                                label: const Text('Hapus', style: TextStyle(fontSize: 12)),
                                onPressed: () => _deleteJournal(item['id'] as int),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. FORMULIR JURNAL KULIT (SkinJournalFormScreen - Buat & Edit)
// ============================================================================

class SkinJournalFormScreen extends StatefulWidget {
  final int? initialBookingId;
  final String? treatmentNama;
  final String? doctorNama;
  final Map<String, dynamic>? existingJournal;

  const SkinJournalFormScreen({
    super.key,
    this.initialBookingId,
    this.treatmentNama,
    this.doctorNama,
    this.existingJournal,
  });

  @override
  State<SkinJournalFormScreen> createState() => _SkinJournalFormScreenState();
}

class _SkinJournalFormScreenState extends State<SkinJournalFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  String? _kondisiKulit;
  late TextEditingController _keluhanCtrl;
  late TextEditingController _catatanCtrl;
  late TextEditingController _produkCtrl;
  String? _photoPath;

  bool _saving = false;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _skinConditions = [
    'Normal',
    'Kering',
    'Berminyak',
    'Kombinasi',
    'Sensitif',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingJournal;

    if (existing != null) {
      DateTime parsed;
      try {
        parsed = DateTime.parse(existing['tanggal']?.toString() ?? '');
      } catch (_) {
        parsed = DateTime.now();
      }
      _selectedDate = parsed;
      _kondisiKulit = existing['kondisi_kulit']?.toString();
      _keluhanCtrl = TextEditingController(text: existing['keluhan']?.toString() ?? '');
      _catatanCtrl = TextEditingController(text: existing['catatan']?.toString() ?? '');
      _produkCtrl = TextEditingController(text: existing['produk']?.toString() ?? '');
      _photoPath = existing['photo_path']?.toString();
    } else {
      _selectedDate = DateTime.now();
      _kondisiKulit = 'Normal';
      _keluhanCtrl = TextEditingController();
      _catatanCtrl = TextEditingController();
      _produkCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _keluhanCtrl.dispose();
    _catatanCtrl.dispose();
    _produkCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingJournal != null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file == null) return;

      // Simpan file ke aplikasi documents directory agar permanen
      final appDir = await getApplicationDocumentsDirectory();
      final ext = file.path.split('.').last;
      final savedPath =
          '${appDir.path}/skin_journal_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final savedFile = await File(file.path).copy(savedPath);

      if (!mounted) return;
      setState(() {
        _photoPath = savedFile.path;
      });
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Gagal mengambil gambar: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Sumber Foto Kulit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: _primary),
                title: const Text('Kamera Langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _primary),
                title: const Text('Galeri Foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_photoPath != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Hapus Foto Terpilih', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _photoPath = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveJournal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_kondisiKulit == null || _kondisiKulit!.isEmpty) {
      snack(context, 'Silakan pilih salah satu kondisi kulit');
      return;
    }

    final uid = myId;
    if (uid == null) {
      snack(context, 'Pengguna tidak valid. Silakan login kembali.');
      return;
    }

    setState(() => _saving = true);

    final isoDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final effectiveBookingId =
        widget.existingJournal?['booking_id'] ?? widget.initialBookingId;

    try {
      if (_isEditing) {
        final id = widget.existingJournal!['id'];
        await db.update(
          'skin_journals',
          {
            'tanggal': isoDate,
            'kondisi_kulit': _kondisiKulit,
            'keluhan': _keluhanCtrl.text.trim(),
            'catatan': _catatanCtrl.text.trim(),
            'produk': _produkCtrl.text.trim(),
            'photo_path': _photoPath,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, uid],
        );

        if (!mounted) return;
        snack(context, 'Jurnal kulit berhasil diperbarui! ✨');
      } else {
        await db.insert('skin_journals', {
          'user_id': uid,
          'booking_id': effectiveBookingId,
          'tanggal': isoDate,
          'kondisi_kulit': _kondisiKulit,
          'keluhan': _keluhanCtrl.text.trim(),
          'catatan': _catatanCtrl.text.trim(),
          'produk': _produkCtrl.text.trim(),
          'photo_path': _photoPath,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (effectiveBookingId != null) {
          final bookingId = effectiveBookingId is int
              ? effectiveBookingId
              : int.tryParse('$effectiveBookingId');
          if (bookingId != null) {
            await syncAftercareReminders(bookingId, userId: uid);
          }
        }

        if (!mounted) return;
        snack(context, 'Jurnal kulit berhasil disimpan! ✨');
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      snack(context, 'Gagal menyimpan jurnal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Jurnal Kulit' : 'Tulis Jurnal Kulit';
    final hasPhoto = _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info treatment jika ada
            if (widget.treatmentNama != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.spa_rounded, color: _primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Terkait Treatment: ${widget.treatmentNama}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Tanggal Jurnal
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.calendar_today_rounded, color: _primary),
                title: const Text('Tanggal Jurnal', style: TextStyle(fontSize: 13, color: Colors.grey)),
                subtitle: Text(
                  _fmtDate(
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined, color: _primary),
                onTap: _pickDate,
              ),
            ),

            const SizedBox(height: 16),

            // 2. Kondisi Kulit (Wajib)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.face_retouching_natural_rounded, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kondisi Kulit Saat Ini *',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pilih kondisi yang paling menggambarkan kulitmu hari ini.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skinConditions.map((cond) {
                        final isSelected = _kondisiKulit == cond;
                        return ChoiceChip(
                          label: Text(cond),
                          selected: isSelected,
                          selectedColor: _primary,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : _textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _kondisiKulit = val ? cond : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Keluhan / Gejala
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keluhan yang Dialami (Opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _keluhanCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sedikit kemerahan di pipi, bruntusan, rasa perih...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Catatan Perkembangan Kulit
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.notes_rounded, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Catatan Perkembangan (Opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _catatanCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan perubahan tekstur, kelembapan, kecerahan, atau respons kulit setelah treatment...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Produk Perawatan yang Digunakan
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.sanitizer_outlined, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Produk Perawatan yang Digunakan (Opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _produkCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sunscreen SPF 50, Krim malam dokter, Centella toner...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 6. Foto Kondisi Kulit (Opsional)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.add_a_photo_outlined, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Foto Kondisi Kulit (Opsional)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unggah foto wajah untuk membandingkan perkembangan dari waktu ke waktu.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    if (hasPhoto) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_photoPath!),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: () {
                                  setState(() => _photoPath = null);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary),
                        ),
                        icon: const Icon(Icons.change_circle_outlined),
                        label: const Text('Ganti Foto'),
                        onPressed: _showImagePickerModal,
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _showImagePickerModal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _primaryLight,
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt_outlined, size: 36, color: _primary),
                              SizedBox(height: 8),
                              Text(
                                'Ambil Foto atau Pilih dari Galeri',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tombol Simpan Jurnal
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _saving ? null : _saveJournal,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _isEditing ? 'Perbarui Jurnal' : 'Simpan Jurnal',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. DETAIL JURNAL KULIT (SkinJournalDetailScreen)
// ============================================================================

class SkinJournalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> journal;
  final String? treatmentNama;
  final String? doctorNama;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const SkinJournalDetailScreen({
    super.key,
    required this.journal,
    this.treatmentNama,
    this.doctorNama,
    this.onDelete,
    this.onEdit,
  });

  Color _badgeColor(String? kondisi) {
    switch (kondisi?.toLowerCase()) {
      case 'normal':
        return Colors.green.shade600;
      case 'kering':
        return Colors.blue.shade600;
      case 'berminyak':
        return Colors.orange.shade700;
      case 'kombinasi':
        return Colors.teal.shade700;
      case 'sensitif':
        return Colors.red.shade600;
      default:
        return _primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final condition = journal['kondisi_kulit']?.toString() ?? 'Normal';
    final bColor = _badgeColor(condition);
    final photoPath = journal['photo_path']?.toString();
    final bool hasPhoto =
        photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();

    final effTreatment =
        treatmentNama ?? journal['booking_treatment_nama']?.toString();
    final effDoctor =
        doctorNama ?? journal['doctor_nama']?.toString();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Detail Jurnal Kulit', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Jurnal',
              onPressed: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus Jurnal',
              onPressed: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: _primary),
                          const SizedBox(width: 8),
                          Text(
                            _fmtDate(journal['tanggal']?.toString()),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: bColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: bColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          condition,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: bColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (effTreatment != null && effTreatment.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: _primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Treatment: $effTreatment',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (effDoctor != null && effDoctor.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dokter: $effDoctor',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Foto Kondisi Kulit
          if (hasPhoto) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(
                    File(photoPath),
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: const [
                        Icon(Icons.photo_camera_outlined, size: 16, color: _primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Foto Kondisi Kulit',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Keluhan
          if (journal['keluhan'] != null &&
              journal['keluhan'].toString().trim().isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Keluhan yang Dialami',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      journal['keluhan'].toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Catatan Perkembangan
          if (journal['catatan'] != null &&
              journal['catatan'].toString().trim().isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.notes_rounded, color: _primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Catatan Perkembangan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      journal['catatan'].toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Produk Perawatan
          if (journal['produk'] != null &&
              journal['produk'].toString().trim().isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.sanitizer_outlined, color: _primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Produk Perawatan yang Digunakan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      journal['produk'].toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Footer info
          Center(
            child: Text(
              'Dicatat pada: ${_fmtTimestamp(journal['created_at']?.toString())}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
