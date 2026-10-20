
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/catalog/api.dart';
import 'package:glowclinic/features/catalog/treatment_api.dart';
import 'package:glowclinic/features/booking/booking_screen.dart';

// ==================== WARNA ====================

const Color pink = Color(0xFF641F35);
const Color pinkDark = Color(0xFF481526);
const Color pinkLight = Color(0xFFF3E4E8);
const Color background = Color(0xFFFFF8F6);
const Color textDark = Color(0xFF49343B);
const Color textMuted = Color(0xFF9A7B84);

// ==================== FOTO TREATMENT ====================

Widget _treatmentImage(String photoUrl, {double iconSize = 32}) {
  final url = photoUrl.trim();

  if (url.isEmpty ||
      !(url.startsWith('https://') || url.startsWith('http://'))) {
    return Container(
      color: pinkLight,
      alignment: Alignment.center,
      child: Icon(Icons.spa_rounded, color: pinkDark, size: iconSize),
    );
  }

  return Image.network(
    url,
    width: double.infinity,
    height: double.infinity,
    fit: BoxFit.cover,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Container(
        color: pinkLight,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: pink),
        ),
      );
    },
    errorBuilder: (_, __, ___) => Container(
      color: pinkLight,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: pinkDark,
        size: iconSize,
      ),
    ),
  );
}

// ==================== UV CARD ====================

class UvCard extends StatelessWidget {
  const UvCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: fetchUv(-6.2, 106.8),
      builder: (context, snapshot) {
        final uv = snapshot.data;
        final high = uv != null && uv >= 6;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE6EE), Color(0xFFFFF0F4)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: pink.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 28,
                  color: high ? Colors.deepOrange : pinkDark,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.hasError
                          ? 'Indeks UV tidak tersedia'
                          : loading
                              ? 'Memuat indeks UV...'
                              : uv == null
                                  ? 'Indeks UV belum tersedia'
                                  : 'Indeks UV hari ini: ${uv.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      high
                          ? 'UV tinggi! Jangan lupa gunakan sunscreen.'
                          : 'Jaga kesehatan kulit sebelum beraktivitas.',
                      style: const TextStyle(
                        color: Color(0xFF856B76),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==================== HALAMAN KATALOG ====================

class Catalog extends StatefulWidget {
  const Catalog({super.key});

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  String category = 'Semua';

  late Future<List<Map<String, dynamic>>> _treatmentFuture;

  static const List<String> categories = [
    'Semua',
    'Facial',
    'Laser',
    'Peeling',
    'Konsultasi',
  ];

  @override
  void initState() {
    super.initState();
    _treatmentFuture = TreatmentApi.fetchTreatments();
  }

  void _reloadTreatments() {
    setState(() {
      _treatmentFuture = TreatmentApi.fetchTreatments();
    });
  }

  IconData categoryIcon(String value) {
    switch (value.toLowerCase()) {
      case 'facial':
        return Icons.face_retouching_natural_rounded;
      case 'laser':
        return Icons.auto_awesome_rounded;
      case 'peeling':
        return Icons.spa_rounded;
      case 'konsultasi':
        return Icons.medical_services_outlined;
      default:
        return Icons.favorite_rounded;
    }
  }

  void _openCategory(String value) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllTreatmentsPage(
          treatmentFuture: _treatmentFuture,
          categories: categories,
          categoryIcon: categoryIcon,
          initialCategory: value,
          onReload: _reloadTreatments,
        ),
      ),
    );
  }

  void _openAllTreatments() => _openCategory('Semua');

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const UvCard(),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kategori Perawatan',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openAllTreatments,
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: pinkDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final item = categories[index];
                final selected = category == item;

                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    categoryIcon(item),
                    size: 17,
                    color: selected ? Colors.white : pinkDark,
                  ),
                  label: Text(item),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: pink,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? pink : pinkLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  onSelected: (_) => _openCategory(item),
                );
              },
            ),
          ),

          const SizedBox(height: 22),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Treatment Pilihan',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Temukan perawatan untuk kulitmu',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openAllTreatments,
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: pinkDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _treatmentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 174,
                  child: Center(
                    child: CircularProgressIndicator(color: pink),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text(
                        'Gagal memuat treatment.',
                        style: TextStyle(color: textDark),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _reloadTreatments,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              final treatments = (snapshot.data ?? []).take(8).toList();

              if (treatments.isEmpty) {
                return const SizedBox(
                  height: 150,
                  child: Center(
                    child: Text(
                      'Belum ada treatment.',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                );
              }

              return TreatmentCarousel(
                treatments: treatments,
                onTap: (treatment) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Detail(treatment),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),
          const DoctorSection(),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}

// ==================== CAROUSEL TREATMENT ====================

class TreatmentCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> treatments;
  final ValueChanged<Map<String, dynamic>> onTap;

  const TreatmentCarousel({
    super.key,
    required this.treatments,
    required this.onTap,
  });

  @override
  State<TreatmentCarousel> createState() => _TreatmentCarouselState();
}

class _TreatmentCarouselState extends State<TreatmentCarousel> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;

  static const double cardWidth = 308;
  static const double cardGap = 12;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;

      final position = _controller.position;
      final max = position.maxScrollExtent;

      if (max <= 0) return;

      final next = _controller.offset + cardWidth + cardGap;

      _controller.animateTo(
        next >= max - 5 ? 0 : next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: widget.treatments.length,
          separatorBuilder: (_, __) => const SizedBox(width: cardGap),
          itemBuilder: (context, index) {
            final t = widget.treatments[index];
            final name = t['nama']?.toString() ?? 'Treatment';
            final kind = t['kategori']?.toString() ?? '-';
            final photo = t['foto_url']?.toString() ?? '';

            return SizedBox(
              width: cardWidth,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onTap(t),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pinkLight),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: double.infinity,
                          child: _treatmentImage(photo, iconSize: 34),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  kind,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: pinkDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Rp ${_formatPrice(t['harga_idr'])}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: pinkDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: pinkDark,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Lihat detail',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== SEMUA TREATMENT ====================

class AllTreatmentsPage extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> treatmentFuture;
  final List<String> categories;
  final IconData Function(String) categoryIcon;
  final VoidCallback onReload;
  final String initialCategory;

  const AllTreatmentsPage({
    super.key,
    required this.treatmentFuture,
    required this.categories,
    required this.categoryIcon,
    required this.onReload,
    required this.initialCategory,
  });

  @override
  State<AllTreatmentsPage> createState() => _AllTreatmentsPageState();
}

class _AllTreatmentsPageState extends State<AllTreatmentsPage> {
  late String category;

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Semua Treatment'),
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.treatmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: pink),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat treatment.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: widget.onReload,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final all = snapshot.data ?? [];

          final filtered = all.where((t) {
            final kind = (t['kategori'] ?? '').toString().trim();
            return category == 'Semua' ||
                kind.toLowerCase() == category.toLowerCase();
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = widget.categories[index];
                    final selected = category == item;

                    return ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        widget.categoryIcon(item),
                        size: 16,
                        color: selected ? Colors.white : pinkDark,
                      ),
                      label: Text(item),
                      selectedColor: pink,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected ? pink : pinkLight,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : textDark,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() => category = item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          category == 'Semua'
                              ? 'Belum ada treatment.'
                              : 'Treatment kategori $category belum tersedia.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                          final photo = t['foto_url']?.toString() ?? '';

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Detail(t),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: pinkLight),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        width: 88,
                                        height: 88,
                                        child: _treatmentImage(photo),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t['nama']?.toString() ?? '-',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            t['kategori']?.toString() ?? '-',
                                            style: const TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Rp ${_formatPrice(t['harga_idr'])}',
                                            style: const TextStyle(
                                              color: pinkDark,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 23,
                                      color: pinkDark,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== DOKTER PILIHAN ====================

class DoctorSection extends StatefulWidget {
  const DoctorSection({super.key});

  @override
  State<DoctorSection> createState() => _DoctorSectionState();
}

class _DoctorSectionState extends State<DoctorSection> {
  late Future<List<Map<String, dynamic>>> _doctorFuture;

  @override
  void initState() {
    super.initState();
    _doctorFuture = qry('SELECT * FROM doctors ORDER BY nama LIMIT 10');
  }

  void _showDoctorDetail(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => DoctorDetailSheet(doctor: doctor),
    );
  }

  void _showAllDoctors() {
    final allDoctorsFuture = qry('SELECT * FROM doctors ORDER BY nama');

    showModalBottomSheet(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pinkLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Semua Dokter',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: allDoctorsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: pink),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Gagal memuat data dokter.'),
                        );
                      }

                      final doctors = snapshot.data ?? [];

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: doctors.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemBuilder: (context, index) {
                          final doctor = doctors[index];
                          final photo =
                              doctor['photo_path']?.toString() ?? '';

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showDoctorDetail(doctor);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: pinkLight),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: Container(
                                          width: double.infinity,
                                          color: pinkLight,
                                          child: _doctorImage(photo, size: 40),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doctor['nama']?.toString() ?? 'Dokter',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: textDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      doctor['spesialisasi']?.toString() ?? '-',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _doctorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: pink)),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Gagal memuat data dokter.'),
          );
        }

        final doctors = snapshot.data ?? [];

        if (doctors.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada data dokter.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dokter Pilihan',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showAllDoctors,
                    child: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: pinkDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final photo =
                        doctor['photo_path']?.toString() ?? '';
                    final schedule =
                        doctor['jadwal_praktik']?.toString().trim() ?? '';

                    return SizedBox(
                      width: 150,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showDoctorDetail(doctor),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: pinkLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 95,
                                    width: double.infinity,
                                    color: pinkLight,
                                    child: _doctorImage(photo, size: 38),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  doctor['nama']?.toString() ?? 'Dokter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctor['spesialisasi']?.toString() ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pinkLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 12,
                                        color: pinkDark,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          schedule.isEmpty
                                              ? 'Jadwal belum tersedia'
                                              : schedule.replaceAll('\n', ' '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: pinkDark,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _doctorImage(String photo, {required double size}) {
  if (photo.startsWith('assets/')) {
    return Image.asset(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        size: size,
        color: pink,
      ),
    );
  }

  return Icon(Icons.person_rounded, size: size, color: pink);
}

// ==================== DETAIL DOKTER ====================

class DoctorDetailSheet extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailSheet({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final photo = doctor['photo_path']?.toString() ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: pinkLight,
                child: ClipOval(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: _doctorImage(photo, size: 55),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                doctor['nama']?.toString() ?? 'Dokter',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                doctor['spesialisasi']?.toString() ?? '-',
                style: const TextStyle(
                  color: pinkDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _info(Icons.school_outlined, 'Pendidikan',
                doctor['pendidikan']?.toString() ?? '-'),
            _info(Icons.work_outline, 'Pengalaman',
                '${doctor['pengalaman_tahun'] ?? 0} tahun'),
            _info(Icons.calendar_month_outlined, 'Jadwal praktik',
                doctor['jadwal_praktik']?.toString() ?? '-'),
            _info(Icons.info_outline, 'Tentang dokter',
                doctor['deskripsi']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: pinkLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: pinkDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: textMuted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DETAIL TREATMENT ====================

class Detail extends StatelessWidget {
  final Map<String, dynamic> t;

  const Detail(this.t, {super.key});

  static const Color _rose = Color(0xFFC47787);
  static const Color _softRose = Color(0xFFF9E8EB);

  @override
  Widget build(BuildContext context) {
    final price = t['harga_idr'];
    final photoUrl = t['foto_url']?.toString().trim() ?? '';
    final name = t['nama']?.toString() ?? 'Detail Treatment';
    final category = t['kategori']?.toString() ?? '-';
    final description =
        t['deskripsi']?.toString() ?? 'Belum ada deskripsi treatment.';
    final duration = t['durasi_menit']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                width: double.infinity,
                height: 245,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _treatmentImage(photoUrl, iconSize: 65),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: pinkDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                color: textDark,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              category,
              style: const TextStyle(
                color: pinkDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: textMuted,
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keunggulan Perawatan',
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: pinkLight),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: _TreatmentBenefit(
                      icon: Icons.spa_outlined,
                      label: 'Perawatan\nkulit',
                    ),
                  ),
                  Expanded(
                    child: _TreatmentBenefit(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Kulit tampak\nlebih segar',
                    ),
                  ),
                  Expanded(
                    child: _TreatmentBenefit(
                      icon: Icons.water_drop_outlined,
                      label: 'Perawatan\nintensif',
                    ),
                  ),
                  Expanded(
                    child: _TreatmentBenefit(
                      icon: Icons.face_retouching_natural,
                      label: 'Kulit lebih\nterawat',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: pinkLight),
                boxShadow: [
                  BoxShadow(
                    color: pink.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga perawatan',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rp ${_formatPrice(price)}',
                          style: const TextStyle(
                            color: pinkDark,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: _rose,
                              size: 19,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '$duration menit',
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: _softRose,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: pinkDark,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F2),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: pinkLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        color: pinkDark,
                        size: 21,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Referensi Kurs',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  FutureBuilder<Map<String, double>>(
                    future: fetchRates(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LinearProgressIndicator(color: pink);
                      }

                      if (snapshot.hasError) {
                        return const Text(
                          'Data kurs belum tersedia.',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        );
                      }

                      final rates = snapshot.data;
                      final numericPrice = price is num
                          ? price.toDouble()
                          : double.tryParse(price?.toString() ?? '');

                      if (rates == null ||
                          rates.isEmpty ||
                          numericPrice == null) {
                        return const Text(
                          'Data kurs belum tersedia.',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 12,
                        runSpacing: 9,
                        children: rates.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (numericPrice * entry.value)
                                      .toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: pinkDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: pink.withValues(alpha: 0.22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(t),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pilih & Booking',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ITEM MANFAAT TREATMENT ====================

class _TreatmentBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TreatmentBenefit({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Color(0xFFF5DDE2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: pinkDark, size: 23),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textDark,
            fontSize: 10,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ==================== FORMAT HARGA ====================

String _formatPrice(dynamic value) {
  final number = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');

  if (number == null) return '-';

  final digits = number.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;

    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}
