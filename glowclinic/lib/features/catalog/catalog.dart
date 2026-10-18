import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/catalog/api.dart';

class UvCard extends StatelessWidget {
  const UvCard({super.key});

  @override
  Widget build(BuildContext c) => FutureBuilder<double?>(
    future: fetchUv(-6.2, 106.8),
    builder: (c, s) {
      final uv = s.data;
      final high = uv != null && uv >= 6;

      return Card(
        color: high ? Colors.red.shade50 : Colors.green.shade50,
        child: ListTile(
          leading: Icon(
            Icons.wb_sunny,
            color: high ? Colors.red : Colors.green,
          ),
          title: Text(
            uv == null ? 'Memuat indeks UV...' : 'Indeks UV hari ini: $uv',
          ),
          subtitle: Text(
            high
                ? 'Tinggi: hindari matahari setelah laser/peeling, pakai SPF.'
                : 'Aman untuk aktivitas luar.',
          ),
        ),
      );
    },
  );
}

class Catalog extends StatefulWidget {
  const Catalog({super.key});

  @override
  State<Catalog> createState() => _C();
}

class _C extends State<Catalog> {
  String q = '';

  @override
  Widget build(BuildContext c) => Column(
    children: [
      const UvCard(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cari layanan',
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: qry('select * from treatments where nama like ?', ['%$q%']),
          builder: (c, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              children: [
                for (final t in s.data!)
                  ListTile(
                    title: Text(t['nama']),
                    subtitle: Text('${t['kategori']} - Rp ${t['harga_idr']}'),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => Detail(t)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class Detail extends StatelessWidget {
  final Map t;

  const Detail(this.t, {super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t['nama'])),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t['deskripsi'] ?? ''),
        const SizedBox(height: 12),
        Text(
          'Rp ${t['harga_idr']}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        FutureBuilder<Map<String, double>>(
          future: fetchRates(),
          builder: (c, s) {
            if (s.hasError) {
              return const Text('Kurs tidak tersedia');
            }

            if (!s.hasData) {
              return const LinearProgressIndicator();
            }

            final p = t['harga_idr'] as int;

            return Text(
              s.data!.entries
                  .map((e) => '${e.key} ${(p * e.value).toStringAsFixed(2)}')
                  .join('  |  '),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
