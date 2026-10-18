import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/catalog/api.dart';
import 'package:glowclinic/features/booking/booking_screen.dart';

class UvCard extends StatelessWidget {
  const UvCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: fetchUv(-6.2, 106.8),
      // TODO: Ganti koordinat dengan lokasi GPS saat modul LBS tersedia.
      builder: (context, snapshot) {
        final uv = snapshot.data;
        final high = uv != null && uv >= 6;

        return Card(
          color: high ? Colors.red.shade50 : Colors.green.shade50,
          child: ListTile(
            leading: Icon(
              Icons.wb_sunny,
              color: high ? Colors.red : Colors.green,
            ),
            title: Text(
              snapshot.hasError
                  ? 'Indeks UV tidak tersedia'
                  : uv == null
                  ? 'Memuat indeks UV...'
                  : 'Indeks UV hari ini: ${uv.toStringAsFixed(1)}',
            ),
            subtitle: Text(
              high
                  ? 'UV tinggi: gunakan perlindungan matahari dan SPF.'
                  : 'Periksa indeks UV sebelum beraktivitas di luar.',
            ),
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const UvCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onChanged: (value) {
              setState(() {
                q = value;
              });
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari layanan',
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: qry('select * from treatments where nama like ?', ['%$q%']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 8),
                        const Text('Gagal memuat daftar layanan.'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final treatments = snapshot.data ?? <Map<String, dynamic>>[];

              if (treatments.isEmpty) {
                return const Center(child: Text('Layanan tidak ditemukan.'));
              }

              return ListView.builder(
                itemCount: treatments.length,
                itemBuilder: (context, index) {
                  final treatment = treatments[index];

                  return ListTile(
                    title: Text(treatment['nama']?.toString() ?? 'Tanpa nama'),
                    subtitle: Text(
                      '${treatment['kategori'] ?? '-'} - '
                      'Rp ${treatment['harga_idr'] ?? '-'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Detail(treatment)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
      appBar: AppBar(title: Text(t['nama']?.toString() ?? 'Detail Layanan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t['deskripsi']?.toString() ?? 'Tidak ada deskripsi.'),
          const SizedBox(height: 12),
          Text(
            'Rp ${price ?? '-'}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, double>>(
            future: fetchRates(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Kurs tidak tersedia.');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
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
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BookingScreen(t)),
              );
            },
            child: const Text('Pilih & Booking'),
          ),
        ],
      ),
    );
  }
}
