
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/catalog/api.dart';
import 'package:glowclinic/features/booking/booking_screen.dart';

const Color pink = Color(0xFFE879A0);
const Color pinkDark = Color(0xFFD85F89);
const Color pinkLight = Color(0xFFFFE1EA);
const Color background = Color(0xFFFFF7F9);
const Color textDark = Color(0xFF59434C);
const Color textMuted = Color(0xFFB08C99);

class UvCard extends StatelessWidget {
  const UvCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: fetchUv(-6.2, 106.8),
      builder: (context, snapshot) {
        final uv = snapshot.data;
        final high = uv != null && uv >= 6;
        final loading =
            snapshot.connectionState == ConnectionState.waiting;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE6EE), Color(0xFFFFF0F4)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: pink.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      high
                          ? 'UV tinggi! Gunakan sunscreen dan SPF.'
                          : 'Jaga kesehatan kulit sebelum beraktivitas.',
                      style: const TextStyle(
                        color: Color(0xFF856B76),
                        fontSize: 12,
                        height: 1.5,
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

class DoctorSection extends StatelessWidget {
  const DoctorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: qry('SELECT * FROM doctors ORDER BY nama LIMIT 10'),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dokter Pilihan',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_rounded,
                    color: pink,
                    size: 20,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 235,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView.separated(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 13),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final photo =
                        doctor['photo_path']?.toString() ?? '';

                    return SizedBox(
                      width: 165,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(21),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(21),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: background,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(26),
                                ),
                              ),
                              builder: (_) =>
                                  DoctorDetailSheet(doctor: doctor),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(
                                color: const Color(0xFFF5DFE7),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    height: 105,
                                    width: double.infinity,
                                    color: pinkLight,
                                    child: photo.startsWith('assets/')
                                        ? Image.asset(
                                            photo,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.person_rounded,
                                              size: 55,
                                              color: pink,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            size: 55,
                                            color: pink,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
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
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pinkLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${doctor['pengalaman_tahun'] ?? 0} tahun pengalaman',
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

class DoctorDetailSheet extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailSheet({
    super.key,
    required this.doctor,
  });

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
                  child: photo.startsWith('assets/')
                      ? Image.asset(
                          photo,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            size: 55,
                            color: pink,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 55,
                          color: pink,
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
            _info(
              Icons.school_outlined,
              'Pendidikan',
              doctor['pendidikan']?.toString() ?? '-',
            ),
            _info(
              Icons.work_outline,
              'Pengalaman',
              '${doctor['pengalaman_tahun'] ?? 0} tahun',
            ),
            _info(
              Icons.calendar_month_outlined,
              'Jadwal praktik',
              doctor['jadwal_praktik']?.toString() ?? '-',
            ),
            _info(
              Icons.info_outline,
              'Tentang dokter',
              doctor['deskripsi']?.toString() ?? '-',
            ),
            const SizedBox(height: 10),
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
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                  ),
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

class Catalog extends StatefulWidget {
  const Catalog({super.key});

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  String q = '';
  String category = 'Semua';

  static const categories = [
    'Semua',
    'Facial',
    'Laser',
    'Peeling',
    'Konsultasi',
  ];

  IconData categoryIcon(String value) {
    switch (value) {
      case 'Facial':
        return Icons.face_retouching_natural_rounded;
      case 'Laser':
        return Icons.auto_awesome_rounded;
      case 'Peeling':
        return Icons.spa_rounded;
      case 'Konsultasi':
        return Icons.medical_services_outlined;
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const UvCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFFF5DFE7),
                ),
              ),
              child: TextField(
                onChanged: (value) => setState(() => q = value),
                decoration: InputDecoration(
                  hintText: 'Cari perawatan kulit...',
                  hintStyle: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: pink,
                  ),
                  suffixIcon: q.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: textMuted,
                          ),
                          onPressed: () => setState(() => q = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Kategori Perawatan',
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  final selected = category == item;

                  return GestureDetector(
                    onTap: () => setState(() => category = item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 83,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: selected ? pink : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? pink
                              : const Color(0xFFF4DFE7),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            categoryIcon(item),
                            color: selected ? Colors.white : pinkDark,
                            size: 25,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white : textDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          const DoctorSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: Text(
              'Pilihan Untukmu',
              style: TextStyle(
                color: textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: qry(
              'SELECT * FROM treatments WHERE nama LIKE ?',
              ['%$q%'],
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(30),
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
                        Icons.error_outline,
                        color: pinkDark,
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      const Text('Gagal memuat daftar layanan.'),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              final treatments =
                  snapshot.data ?? <Map<String, dynamic>>[];

              final filtered = treatments.where((t) {
                if (category == 'Semua') return true;

                return (t['kategori']?.toString().toLowerCase() ?? '') ==
                    category.toLowerCase();
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(25),
                  child: Center(
                    child: Text(
                      'Layanan tidak ditemukan.',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final treatment = filtered[index];
                  final name =
                      treatment['nama']?.toString() ?? 'Tanpa nama';
                  final kind =
                      treatment['kategori']?.toString() ?? '-';
                  final price = treatment['harga_idr'];

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Detail(treatment),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color: const Color(0xFFF5E4EA),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 57,
                              height: 57,
                              decoration: BoxDecoration(
                                color: pinkLight,
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Icon(
                                categoryIcon(kind),
                                color: pinkDark,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    kind,
                                    style: const TextStyle(
                                      color: textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    'Rp ${price ?? '-'}',
                                    style: const TextStyle(
                                      color: pinkDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: pinkDark,
                              size: 15,
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
        ],
      ),
    );
  }
}

class Detail extends StatelessWidget {
  final Map<String, dynamic> t;

  const Detail(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final price = t['harga_idr'];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(t['nama']?.toString() ?? 'Detail Layanan'),
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFE1EA),
                  Color(0xFFFFF0F4),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: pinkDark,
              size: 65,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            t['nama']?.toString() ?? 'Detail Layanan',
            style: const TextStyle(
              color: textDark,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t['deskripsi']?.toString() ?? 'Tidak ada deskripsi.',
            style: const TextStyle(
              color: Color(0xFF856B76),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pinkLight),
            ),
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
                const SizedBox(height: 6),
                Text(
                  'Rp ${price ?? '-'}',
                  style: const TextStyle(
                    color: pinkDark,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Referensi Kurs',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, double>>(
            future: fetchRates(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Kurs tidak tersedia.');
              }

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const LinearProgressIndicator(color: pink);
              }

              final rates = snapshot.data;

              if (rates == null || rates.isEmpty) {
                return const Text('Data kurs belum tersedia.');
              }

              final numericPrice = price is num
                  ? price.toDouble()
                  : double.tryParse(price?.toString() ?? '');

              if (numericPrice == null) {
                return const Text(
                  'Harga layanan tidak valid untuk konversi kurs.',
                );
              }

              return Text(
                rates.entries
                    .map(
                      (entry) =>
                          '${entry.key} '
                          '${(numericPrice * entry.value).toStringAsFixed(2)}',
                    )
                    .join('  |  '),
                style: const TextStyle(
                  color: textDark,
                  fontSize: 12,
                  height: 1.8,
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(t),
                  ),
                );
              },
              child: const Text(
                'Pilih & Booking',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
