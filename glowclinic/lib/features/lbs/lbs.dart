import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:glowclinic/features/notif/inbox.dart';
import 'package:glowclinic/core/core.dart';

double? _coordinate(dynamic value) {
  if (value == null) {
    return null;
  }

  return double.tryParse(value.toString());
}

/// Membuka lokasi cabang di Google Maps (aplikasi atau browser).
Future<void> openBranchInMaps(
  BuildContext context,
  Map<String, dynamic> branch,
) async {
  final lat = _coordinate(branch['lat']);
  final lng = _coordinate(branch['lng']);

  if (lat == null || lng == null) {
    snack(context, 'Koordinat cabang tidak valid.');
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$lat,$lng',
  });

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      snack(context, 'Tidak dapat membuka Google Maps.');
    }
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Tidak dapat membuka Google Maps.');
    }
  }
}

Future<Position?> myPos() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
}

/// Mengembalikan true jika check-in berhasil.
Future<bool> doCheckIn(BuildContext context, Map booking) async {
  if (booking['status'] != 'confirmed') {
    snack(context, 'Check-in hanya tersedia untuk booking terkonfirmasi.');
    return false;
  }

  try {
    final position = await myPos();

    if (!context.mounted) {
      return false;
    }

    if (position == null) {
      snack(context, 'Aktifkan layanan lokasi dan izinkan akses lokasi.');
      return false;
    }

    final branches = await qry('select lat, lng from branches where id = ?', [
      booking['branch_id'],
    ]);

    if (!context.mounted) {
      return false;
    }

    if (branches.isEmpty) {
      snack(context, 'Data cabang tidak ditemukan.');
      return false;
    }

    final latitude = _coordinate(branches.first['lat']);
    final longitude = _coordinate(branches.first['lng']);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      snack(context, 'Koordinat cabang tidak valid.');
      return false;
    }

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );

    if (distance > 100) {
      snack(
        context,
        'Kamu belum berada dalam radius 100 m dari cabang '
        '(jarak ${distance.toStringAsFixed(0)} m).',
      );
      return false;
    }

    final updated = await db.update(
      'bookings',
      {'status': 'checked_in'},
      where: 'id = ? AND status = ?',
      whereArgs: [booking['id'], 'confirmed'],
    );

    if (updated == 0) {
      if (context.mounted) {
        snack(context, 'Status booking berubah. Muat ulang daftar booking.');
      }
      return false;
    }

    final who = '${booking['u_nama'] ?? 'Pasien'}';
    final what = '${booking['t_nama'] ?? 'treatment'}';

    await pushNotif(
      toStaff: true,
      judul: 'Pasien sudah check-in 📍',
      isi: '$who tiba di klinik untuk $what.',
      tipe: 'booking',
      bookingId: booking['id'] as int?,
    );

    await pushNotif(
      userId: myId,
      judul: 'Check-in berhasil ✅',
      isi: 'Silakan lanjutkan pembayaran QRIS untuk $what.',
      tipe: 'bayar',
      bookingId: booking['id'] as int?,
    );

    if (!context.mounted) {
      return true;
    }

    snack(context, 'Check-in berhasil. Lanjutkan pembayaran.');
    return true;
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Check-in gagal. Periksa koneksi dan coba lagi.');
    }
    return false;
  }
}



class BranchMap extends StatefulWidget {
  const BranchMap({super.key});

  @override
  State<BranchMap> createState() => _BranchMapState();
}

class _BranchMapState extends State<BranchMap> {
  List<Map<String, dynamic>> branches = [];
  Position? position;
  bool loaded = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loaded = false;
      loadError = null;
    });

    try {
      final result = await qry('select * from branches');
      final branchList = List<Map<String, dynamic>>.from(result);

      final currentPosition = await myPos();

      if (currentPosition != null) {
        for (final branch in branchList) {
          final lat = _coordinate(branch['lat']);
          final lng = _coordinate(branch['lng']);

          if (lat == null ||
              lng == null ||
              lat < -90 ||
              lat > 90 ||
              lng < -180 ||
              lng > 180) {
            continue;
          }

          branch['jarak'] = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            lat,
            lng,
          );
        }

        branchList.sort((a, b) {
          final distanceA = _coordinate(a['jarak']);
          final distanceB = _coordinate(b['jarak']);

          if (distanceA == null && distanceB == null) {
            return 0;
          }
          if (distanceA == null) {
            return 1;
          }
          if (distanceB == null) {
            return -1;
          }

          return distanceA.compareTo(distanceB);
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        branches = branchList;
        position = currentPosition;
        loaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadError = 'Gagal memuat data cabang.';
        loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadError!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (branches.isEmpty) {
      return const Center(child: Text('Belum ada cabang'));
    }

    final validBranches = branches.where((branch) {
      final lat = _coordinate(branch['lat']);
      final lng = _coordinate(branch['lng']);

      return lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180;
    }).toList();

    final center = position != null
        ? LatLng(position!.latitude, position!.longitude)
        : validBranches.isNotEmpty
        ? LatLng(
            _coordinate(validBranches.first['lat'])!,
            _coordinate(validBranches.first['lng'])!,
          )
        : const LatLng(0, 0);

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12.5, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.glowclinic',
              ),
              MarkerLayer(
                markers: [
                  for (final branch in validBranches)
                    Marker(
                      point: LatLng(
                        _coordinate(branch['lat'])!,
                        _coordinate(branch['lng'])!,
                      ),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => openBranchInMaps(context, branch),
                        child: const Icon(Icons.location_on, color: Colors.pink, size: 40),
                      ),
                    ),
                  if (position != null)
                    Marker(
                      point: center,
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                final distance = _coordinate(branch['jarak']);

                return ListTile(
                  leading: const Icon(Icons.local_hospital),
                  onTap: () => openBranchInMaps(context, branch),
                  title: Text(branch['nama']?.toString() ?? 'Cabang'),
                  subtitle: Text(
                    '${branch['alamat'] ?? '-'}\n'
                    'Buka ${branch['jam_buka'] ?? '-'}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions, color: Colors.pink),
                      const SizedBox(height: 2),
                      Text(
                        distance == null
                            ? '-'
                            : distance < 1000
                                ? '${distance.toStringAsFixed(0)} m'
                                : '${(distance / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
