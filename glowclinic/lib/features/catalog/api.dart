import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:glowclinic/core/core.dart';

/// Open-Meteo: indeks UV (tanpa API key)
Future<double?> fetchUv(double lat, double lng) async {
  final r = await http.get(
    Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=uv_index',
    ),
  );
  return (jsonDecode(r.body)['current']['uv_index'] as num?)?.toDouble();
}

/// Frankfurter: kurs IDR -> USD, EUR, JPY (cache di secure storage)
Map<String, double> _parse(String b) => (jsonDecode(b)['rates'] as Map).map(
  (k, v) => MapEntry(k as String, (v as num).toDouble()),
);
Future<Map<String, double>> fetchRates() async {
  try {
    final r = await http.get(
      Uri.parse('https://api.frankfurter.app/latest?from=IDR&to=USD,EUR,JPY'),
    );
    await store.write(key: 'rates', value: r.body);
    return _parse(r.body);
  } catch (_) {
    final c = await store.read(key: 'rates');
    if (c != null) return _parse(c);
    rethrow;
  }
}
