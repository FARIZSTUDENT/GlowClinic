import 'package:flutter/material.dart';
import 'package:glowclinic/core/core.dart';
import 'package:glowclinic/features/notif/notif.dart';
import 'package:glowclinic/features/lbs/lbs.dart';
import 'package:glowclinic/features/booking/timezone_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _ST();
}

class _ST extends State<SettingsScreen> {
  Future<void> updateBranchLocation() async {
    final position = await myPos();

    if (!mounted) return;

    if (position == null) {
      snack(context, 'Izin lokasi diperlukan');
      return;
    }

    try {
      final result = await db.update(
        'branches',
        {'lat': position.latitude, 'lng': position.longitude},
        where: 'id = ?',
        whereArgs: [1],
      );

      if (!mounted) return;

      snack(
        context,
        result > 0
            ? 'Lokasi cabang diperbarui'
            : 'Cabang dengan ID 1 tidak ditemukan',
      );
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal memperbarui lokasi cabang');
      }
    }
  }

  Future<void> testNotification() async {
    try {
      await notify(
        999999,
        'GlowClinic',
        'Notifikasi berjalan dengan baik',
        DateTime.now().add(const Duration(seconds: 5)),
      );

      if (mounted) {
        snack(context, 'Tes notifikasi dijadwalkan');
      }
    } catch (e) {
      if (mounted) {
        snack(context, 'Gagal menjadwalkan notifikasi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.fingerprint_rounded),
            title: Text('Login biometrik'),
            subtitle: Text(
              'Selalu aktif. Password dipakai setelah biometrik gagal 3 kali.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Jadikan lokasi saya sebagai lokasi cabang'),
            subtitle: const Text('Untuk menguji check-in saat demo'),
            onTap: updateBranchLocation,
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Tes notifikasi (5 detik)'),
            onTap: testNotification,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Konversi Waktu'),
            subtitle: const Text(
              'WIB, WITA, WIT, dan London (dengan DST otomatis)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TimeZoneConversionScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ValueListenableBuilder<String>(
            valueListenable: CurrencyService.activeCurrency,
            builder: (context, activeCurr, _) {
              final info = supportedCurrencies[activeCurr] ?? supportedCurrencies['IDR']!;
              return ListTile(
                leading: const Icon(Icons.currency_exchange_rounded),
                title: const Text('Mata Uang Pembayaran'),
                subtitle: Text(
                  '${info.flag} ${info.code} - ${info.name} (${info.symbol})\n'
                  'Sumber kurs: ${CurrencyService.ratesSource}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCurrencyPicker,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final active = CurrencyService.activeCurrency.value;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pilih Mata Uang Pembayaran',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Perbarui Kurs',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () async {
                            await CurrencyService.fetchAndCacheRates(force: true);
                            if (sheetContext.mounted) {
                              setModalState(() {});
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih mata uang untuk estimasi harga, ringkasan booking, dan pembayaran.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...supportedCurrencies.values.map((curr) {
                      final isSelected = curr.code == active;
                      final rateDesc = CurrencyService.formatRateDescription(curr.code);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF641F35)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.8 : 1,
                          ),
                          color: isSelected
                              ? const Color(0xFFFBF4F6)
                              : Colors.white,
                        ),
                        child: ListTile(
                          leading: Text(
                            curr.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          title: Text(
                            '${curr.name} (${curr.symbol})',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            rateDesc,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF641F35),
                                )
                              : null,
                          onTap: () async {
                            await CurrencyService.setCurrency(curr.code);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Catatan Pembayaran: Sistem pembayaran QRIS nasional memproses settlement dalam Rupiah (IDR). Nominal dalam mata uang asing ditampilkan sebagai estimasi konversi transparan.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
