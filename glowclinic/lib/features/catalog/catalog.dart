
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/catalog/api.dart';
import 'package:glowclinic/features/catalog/treatment_api.dart';
import 'package:glowclinic/features/booking/booking_screen.dart';

// ==================== TEMA ====================

const Color pink = Color(0xFF641F35);
const Color pinkDark = Color(0xFF481526);
const Color pinkLight = Color(0xFFF3E4E8);
const Color background = Color(0xFFFFF8F6);
const Color textDark = Color(0xFF49343B);
const Color textMuted = Color(0xFF9A7B84);
const Color blush = Color(0xFFFFEDF1);

BoxDecoration _cardDecoration({double radius = 22}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: pinkLight),
  boxShadow: [
    BoxShadow(
      color: pink.withValues(alpha: 0.055),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

TextStyle _heading(double size) => TextStyle(
  color: textDark,
  fontSize: size,
  fontWeight: FontWeight.w800,
  height: 1.2,
);

Widget _sectionHeading(
  String title, {
  String? subtitle,
  VoidCallback? onSeeAll,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 18, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _heading(19)),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
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
  );
}

// ==================== FOTO TREATMENT ====================

Widget _treatmentImage(String photoUrl, {double iconSize = 32}) {
  final url = photoUrl.trim();

  if (url.isEmpty ||
      !(url.startsWith('https://') || url.startsWith('http://'))) {
    return Container(
      color: blush,
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
        color: blush,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: pink,
          ),
        ),
      );
    },
    errorBuilder: (_, __, ___) => Container(
      color: blush,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: pinkDark,
        size: iconSize,
      ),
    ),
  );
}

Widget _doctorImage(String photo, {required double size}) {
  final path = photo.trim();

  if (path.startsWith('assets/')) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        size: size,
        color: pink,
      ),
    );
  }

  if (path.startsWith('https://') || path.startsWith('http://')) {
    return Image.network(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        size: size,
        color: pink,
      ),
    );
  }

  return Icon(Icons.person_rounded, size: size, color: pink);
}

// ==================== KARTU UV ====================

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
          margin: const EdgeInsets.fromLTRB(18, 12, 18, 25),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE5EC), Color(0xFFFFF5F4)],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: pink.withValues(alpha: 0.09),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 29,
                  color: high ? Colors.deepOrange : pinkDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skin Protection',
                      style: TextStyle(
                        color: pinkDark,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      snapshot.hasError
                          ? 'Indeks UV tidak tersedia'
                          : loading
                              ? 'Memuat indeks UV...'
                              : uv == null
                                  ? 'Indeks UV belum tersedia'
                                  : 'Indeks UV hari ini: ${uv.toStringAsFixed(1)}',
                      style: _heading(14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      high
                          ? 'UV tinggi! Jangan lupa gunakan sunscreen.'
                          : 'Jaga kesehatan kulit sebelum beraktivitas.',
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 11,
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
    'Injectable',
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
      case 'semua':
        return Icons.local_florist_outlined;
      case 'facial':
        return Icons.face_3_outlined;
      case 'laser':
        return Icons.auto_awesome_outlined;
      case 'peeling':
        return Icons.water_drop_outlined;
      case 'injectable':
        return Icons.vaccines_outlined;
      case 'konsultasi':
        return Icons.medical_services_outlined;
      default:
        return Icons.local_florist_outlined;
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
          _sectionHeading(
            'Kategori Perawatan',
            subtitle: 'Pilih perawatan sesuai kebutuhan kulitmu',
            onSeeAll: _openAllTreatments,
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = categories[index];
                return _CategoryPill(
                  label: item,
                  icon: categoryIcon(item),
                  selected: category == item,
                  onTap: () => _openCategory(item),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _sectionHeading(
            'Treatment Pilihan',
            subtitle: 'Temukan perawatan terbaik untuk kulitmu',
            onSeeAll: _openAllTreatments,
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _treatmentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 205,
                  child: Center(
                    child: CircularProgressIndicator(color: pink),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: pinkDark,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gagal memuat treatment.',
                        style: TextStyle(color: textDark),
                      ),
                      TextButton(
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
          const SizedBox(height: 32),
        DoctorSection(),
          const SizedBox(height: 30),
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

  static const double cardWidth = 310;
  static const double cardGap = 13;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TreatmentCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treatments.length != widget.treatments.length &&
        _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;

      final max = _controller.position.maxScrollExtent;
      if (max <= 0) return;

      final next = _controller.offset + cardWidth + cardGap;

      _controller.animateTo(
        next >= max - 5 ? 0 : next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
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
      height: 188,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
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
                borderRadius: BorderRadius.circular(23),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onTap(t),
                  child: Container(
                    decoration: _cardDecoration(radius: 23),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 126,
                          height: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _treatmentImage(photo, iconSize: 34),
                              Positioned(
                                left: 9,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    kind,
                                    style: const TextStyle(
                                      color: pinkDark,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'GLOW SIGNATURE',
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 8,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _heading(13),
                                ),
                                const Spacer(),
                                ValueListenableBuilder<String>(
                                  valueListenable: CurrencyService.activeCurrency,
                                  builder: (context, activeCurr, _) {
                                    final priceIdr = (t['harga_idr'] as num?)?.toInt() ?? 0;
                                    return Text(
                                      CurrencyService.formatConverted(
                                        priceIdr,
                                        targetCurrency: activeCurr,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: pinkDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                const Row(
                                  children: [
                                    Text(
                                      'Lihat detail',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: pinkDark,
                                      size: 13,
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
        title: const Text(
          'Semua Treatment',
          style: TextStyle(fontWeight: FontWeight.w800, color: textDark),
        ),
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = widget.categories[index];
                    return _CategoryPill(
                      label: item,
                      icon: widget.categoryIcon(item),
                      selected: category == item,
                      onTap: () => setState(() => category = item),
                    );
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Text(
                            category == 'Semua'
                                ? 'Belum ada treatment.'
                                : 'Treatment kategori $category belum tersedia.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                          final photo = t['foto_url']?.toString() ?? '';

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(21),
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
                                padding: const EdgeInsets.all(11),
                                decoration: _cardDecoration(radius: 21),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: SizedBox(
                                        width: 92,
                                        height: 96,
                                        child: _treatmentImage(photo),
                                      ),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (t['kategori'] ?? '-').toString(),
                                            style: const TextStyle(
                                              color: pinkDark,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            t['nama']?.toString() ?? '-',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: _heading(14),
                                          ),
                                          const SizedBox(height: 9),
                                          ValueListenableBuilder<String>(
                                            valueListenable: CurrencyService.activeCurrency,
                                            builder: (context, activeCurr, _) {
                                              final priceIdr = (t['harga_idr'] as num?)?.toInt() ?? 0;
                                              return Text(
                                                CurrencyService.formatConverted(
                                                  priceIdr,
                                                  targetCurrency: activeCurr,
                                                ),
                                                style: const TextStyle(
                                                  color: pinkDark,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: pinkDark,
                                      size: 23,
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

// ==================== KATEGORI ====================

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF70263D);
    const inactiveBorderColor = Color(0xFFF0DDE2);

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? selectedColor : inactiveBorderColor,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            splashColor: selectedColor.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : selectedColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : selectedColor,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== DAFTAR DOKTER ====================

class DoctorSection extends StatefulWidget {
  const DoctorSection({super.key});

  @override
  State<DoctorSection> createState() => _DoctorSectionState();
}

class _DoctorSectionState extends State<DoctorSection> {
  final ScrollController _scrollController = ScrollController();

  late Future<List<Map<String, dynamic>>> _doctorFuture;
  Timer? _autoSlideTimer;

  static const double _cardWidth = 145;
  static const double _cardGap = 10;

  @override
  void initState() {
    super.initState();

    _doctorFuture = qry(
      'SELECT * FROM doctors ORDER BY nama LIMIT 10',
    );

    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _autoSlide(),
    );
  }

  void _autoSlide() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.maxScrollExtent <= 0) return;

    final nextOffset = _scrollController.offset + _cardWidth + _cardGap;

    if (nextOffset >= position.maxScrollExtent - 5) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.animateTo(
        nextOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showDoctorDetail(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (_) => DoctorDetailSheet(doctor: doctor),
    );
  }

  void _showAllDoctors() {
    final allDoctorsFuture = qry(
      'SELECT * FROM doctors ORDER BY nama',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pinkLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
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
                          child: CircularProgressIndicator(
                            color: pink,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Gagal memuat data dokter.'),
                        );
                      }

                      final doctors = snapshot.data ?? [];

                      if (doctors.isEmpty) {
                        return const Center(
                          child: Text('Belum ada data dokter.'),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: doctors.length,
                        itemBuilder: (context, index) {
                          final doctor = doctors[index];
                          final photo =
                              doctor['photo_path']?.toString() ?? '';
                          final name =
                              doctor['nama']?.toString() ?? 'Dokter';
                          final specialization =
                              doctor['spesialisasi']?.toString() ?? '-';
                          final schedule =
                              doctor['jadwal_praktik']?.toString().trim() ??
                                  '';

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(13),
                                        child: Container(
                                          width: double.infinity,
                                          color: pinkLight,
                                          child: photo.startsWith('assets/')
                                              ? Image.asset(
                                                  photo,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          const Icon(
                                                    Icons.person_rounded,
                                                    color: pink,
                                                    size: 44,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person_rounded,
                                                  color: pink,
                                                  size: 44,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      specialization,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    if (schedule.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pinkLight,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          schedule,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: pinkDark,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
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
  void dispose() {
    _autoSlideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _doctorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: pink),
            ),
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
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dokter Pilihan',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Material(
                    color: const Color(0xFFFFE6EE),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _showAllDoctors,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF5DFE7),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See All',
                              style: TextStyle(
                                color: pinkDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: pinkDark,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 210,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _cardGap),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final photo =
                        doctor['photo_path']?.toString() ?? '';
                    final schedule =
                        doctor['jadwal_praktik']?.toString().trim() ?? '';

                    return SizedBox(
                      width: _cardWidth,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => _showDoctorDetail(doctor),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: const Color(0xFFF5DFE7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 72,
                                    width: double.infinity,
                                    color: pinkLight,
                                    child: photo.startsWith('assets/')
                                        ? Image.asset(
                                            photo,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.person_rounded,
                                              size: 40,
                                              color: pink,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            size: 40,
                                            color: pink,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  doctor['nama']?.toString() ?? 'Dokter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  doctor['spesialisasi']?.toString() ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFB547),
                                      size: 13,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '4,9',
                                      style: TextStyle(
                                        color: textDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      ' / 5,0',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pinkLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        color: pinkDark,
                                        size: 11,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          schedule.isEmpty
                                              ? 'Jadwal belum tersedia'
                                              : schedule,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: pinkDark,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            height: 1.15,
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

// ==================== DETAIL DOKTER ====================

class DoctorDetailSheet extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailSheet({
    super.key,
    required this.doctor,
  });

  static const Color wine = Color(0xFF64263D);
  static const Color wineDark = Color(0xFF421728);
  static const Color ivory = Color(0xFFFFFAF7);
  static const Color muted = Color(0xFF967A83);
  static const Color line = Color(0xFFEFE3E5);

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final content = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: wine,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: const TextStyle(
                    color: wineDark,
                    fontSize: 13,
                    height: 1.5,
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

  @override
  Widget build(BuildContext context) {
    final photo = doctor['photo_path']?.toString() ?? '';
    final name = doctor['nama']?.toString() ?? 'Dokter';
    final specialization =
        doctor['spesialisasi']?.toString() ?? 'Dokter Profesional';
    final education = doctor['pendidikan']?.toString() ?? '-';
    final experience =
        doctor['pengalaman_tahun']?.toString() ?? '0';
    final schedule = doctor['jadwal_praktik']?.toString() ?? '-';
    final description = doctor['deskripsi']?.toString() ?? '';

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: const BoxDecoration(
            color: ivory,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCC8CE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Profil Dokter',
                        style: TextStyle(
                          color: wineDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: wine,
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: line),

              // Konten profil
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto dan nama dokter
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF4E3E7),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _doctorImage(photo, size: 45),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: wineDark,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              specialization,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Pengalaman
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E9EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.work_outline_rounded,
                              color: wine,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Pengalaman praktik',
                                style: TextStyle(
                                  color: wineDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '$experience tahun',
                              style: const TextStyle(
                                color: wine,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'Tentang Dokter',
                        style: TextStyle(
                          color: wineDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description.trim().isEmpty
                            ? 'Informasi profil dokter belum tersedia.'
                            : description.trim(),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),

                      const SizedBox(height: 26),

                      const Text(
                        'Informasi',
                        style: TextStyle(
                          color: wineDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      _infoRow(
                        icon: Icons.school_outlined,
                        title: 'Pendidikan',
                        value: education,
                      ),

                      const Divider(height: 1, color: line),

                      _infoRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'Jadwal Praktik',
                        value: schedule,
                      ),

                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: muted,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Jadwal praktik dapat berubah. '
                                'Silakan konfirmasi jadwal saat melakukan '
                                'pemesanan.',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  height: 1.6,
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
            ],
          ),
        ),
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: SizedBox(
                width: double.infinity,
                height: 255,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _treatmentImage(photoUrl, iconSize: 65),
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: pinkDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: pinkDark.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'GLOW SIGNATURE TREATMENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 23),
            Text(name, style: _heading(27)),
            const SizedBox(height: 9),
            Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: pinkDark,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              description,
              style: const TextStyle(
                color: textMuted,
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 25),
            Text('Keunggulan Perawatan', style: _heading(18)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(23),
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
              padding: const EdgeInsets.all(21),
              decoration: _cardDecoration(radius: 25),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HARGA PERAWATAN',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String>(
                          valueListenable: CurrencyService.activeCurrency,
                          builder: (context, activeCurr, _) {
                            final priceIdr = (price as num?)?.toInt() ?? 0;
                            final converted = CurrencyService.formatConverted(
                              priceIdr,
                              targetCurrency: activeCurr,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  converted,
                                  style: const TextStyle(
                                    color: pinkDark,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (activeCurr != 'IDR') ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Dasar: Rp ${_formatPrice(priceIdr)}',
                                    style: const TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: _rose,
                              size: 18,
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
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: _softRose,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: pinkDark,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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

                      final rates = snapshot.data ?? CurrencyService.currentRates;
                      final numericPrice = price is num
                          ? price.toDouble()
                          : double.tryParse(price?.toString() ?? '');

                      if (numericPrice == null) {
                        return const Text(
                          'Data harga tidak valid.',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        );
                      }

                      return ValueListenableBuilder<String>(
                        valueListenable: CurrencyService.activeCurrency,
                        builder: (context, activeCurr, _) {
                          final allCurrs = supportedCurrencies.keys;
                          return Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: allCurrs.map((code) {
                              final isSelected = code == activeCurr;
                              final rate = rates[code] ?? CurrencyService.getRate(code);
                              final converted = CurrencyService.convertFromIdr(
                                numericPrice,
                                code,
                                customRate: rate,
                              );
                              final formatted = CurrencyService.formatMoney(
                                converted,
                                code,
                              );

                              return InkWell(
                                onTap: () => CurrencyService.setCurrency(code),
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFBF4F6)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: isSelected ? pinkDark : pinkLight,
                                      width: isSelected ? 1.6 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            code,
                                            style: TextStyle(
                                              color: isSelected ? pinkDark : textMuted,
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 11,
                                              color: pinkDark,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatted,
                                        style: TextStyle(
                                          color: isSelected ? pinkDark : textDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
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
                onPressed: () async {
                  final message = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(t),
                    ),
                  );

                  if (message != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
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

// ==================== MANFAAT TREATMENT ====================

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
          width: 43,
          height: 43,
          decoration: const BoxDecoration(
            color: Color(0xFFF5DDE2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: pinkDark, size: 22),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: textDark,
            fontSize: 9,
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