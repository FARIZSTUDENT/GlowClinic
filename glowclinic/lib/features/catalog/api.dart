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

/// Frankfurter: kurs IDR -> USD, EUR, JPY dengan fallback cache & offline
Future<Map<String, double>> fetchRates() => CurrencyService.fetchAndCacheRates();
