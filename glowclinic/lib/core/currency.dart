import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:glowclinic/core/core.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final int decimals;
  final String flag;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.flag,
  });
}

const Map<String, CurrencyInfo> supportedCurrencies = {
  'IDR': CurrencyInfo(
    code: 'IDR',
    name: 'Rupiah Indonesia',
    symbol: 'Rp',
    decimals: 0,
    flag: '🇮🇩',
  ),
  'USD': CurrencyInfo(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
    decimals: 2,
    flag: '🇺🇸',
  ),
  'EUR': CurrencyInfo(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
    decimals: 2,
    flag: '🇪🇺',
  ),
  'JPY': CurrencyInfo(
    code: 'JPY',
    name: 'Japanese Yen',
    symbol: '¥',
    decimals: 0,
    flag: '🇯🇵',
  ),
};

/// Standar kurs fallback (Jumlah mata uang tujuan per 1 IDR).
/// Digunakan bila koneksi jaringan belum tersedia atau API gagal dihubungi.
const Map<String, double> kFallbackRates = {
  'IDR': 1.0,
  'USD': 0.000062, // 1 USD ≈ Rp 16.129
  'EUR': 0.000058, // 1 EUR ≈ Rp 17.241
  'JPY': 0.0094,   // 1 JPY ≈ Rp 106,38
};

class CurrencyService {
  static final ValueNotifier<String> activeCurrency = ValueNotifier<String>('IDR');
  static Map<String, double> currentRates = Map.from(kFallbackRates);
  static String ratesSource = 'Standar';
  static DateTime? ratesUpdatedAt;

  /// Inisialisasi mata uang dari storage dan muat kurs.
  static Future<void> init() async {
    try {
      final savedCurrency = await store.read(key: 'pref_currency');
      if (savedCurrency != null && supportedCurrencies.containsKey(savedCurrency)) {
        activeCurrency.value = savedCurrency;
      }
    } catch (_) {}

    await fetchAndCacheRates();
  }

  /// Ubah mata uang aktif dan simpan secara persisten.
  static Future<void> setCurrency(String code) async {
    if (!supportedCurrencies.containsKey(code)) return;
    activeCurrency.value = code;
    try {
      await store.write(key: 'pref_currency', value: code);
    } catch (_) {}
  }

  /// Ambil kurs dari Frankfurter API (IDR -> USD, EUR, JPY) dengan fallback cache & offline.
  static Future<Map<String, double>> fetchAndCacheRates({bool force = false}) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://api.frankfurter.app/latest?from=IDR&to=USD,EUR,JPY'),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ratesMap = (data['rates'] as Map).map(
          (k, v) => MapEntry(k.toString().toUpperCase(), (v as num).toDouble()),
        );

        ratesMap['IDR'] = 1.0;
        currentRates = {...kFallbackRates, ...ratesMap};
        ratesSource = 'Live';
        ratesUpdatedAt = DateTime.now();

        await store.write(key: 'rates', value: response.body);
        await store.write(
          key: 'rates_updated_at',
          value: ratesUpdatedAt!.toIso8601String(),
        );

        return currentRates;
      }
    } catch (_) {}

    // Fallback ke cache di storage
    try {
      final cachedBody = await store.read(key: 'rates');
      if (cachedBody != null) {
        final data = jsonDecode(cachedBody);
        final ratesMap = (data['rates'] as Map).map(
          (k, v) => MapEntry(k.toString().toUpperCase(), (v as num).toDouble()),
        );
        ratesMap['IDR'] = 1.0;
        currentRates = {...kFallbackRates, ...ratesMap};
        ratesSource = 'Cache';

        final updatedStr = await store.read(key: 'rates_updated_at');
        if (updatedStr != null) {
          ratesUpdatedAt = DateTime.tryParse(updatedStr);
        }
        return currentRates;
      }
    } catch (_) {}

    // Fallback ke kFallbackRates
    currentRates = Map.from(kFallbackRates);
    ratesSource = 'Standar (Offline)';
    return currentRates;
  }

  /// Ambil nilai kurs untuk mata uang tertentu (Mata uang per 1 IDR).
  static double getRate(String currencyCode) {
    return currentRates[currencyCode] ?? kFallbackRates[currencyCode] ?? 1.0;
  }

  /// Konversi nominal dari IDR ke mata uang tujuan.
  /// Nominal IDR selalu menjadi dasar (base currency) agar tidak terjadi konversi berulang.
  static double convertFromIdr(num idrAmount, String targetCurrency, {double? customRate}) {
    if (targetCurrency == 'IDR') return idrAmount.toDouble();
    final rate = customRate ?? getRate(targetCurrency);
    return idrAmount * rate;
  }

  /// Format angka nominal sesuai kaidah mata uang.
  static String formatAmount(num amount, String currencyCode) {
    final info = supportedCurrencies[currencyCode] ?? supportedCurrencies['IDR']!;
    if (info.decimals == 0) {
      final rounded = amount.round();
      final digits = rounded.toString();
      final buffer = StringBuffer();
      for (var i = 0; i < digits.length; i++) {
        buffer.write(digits[i]);
        final rem = digits.length - i - 1;
        if (rem > 0 && rem % 3 == 0) {
          buffer.write(currencyCode == 'IDR' ? '.' : ',');
        }
      }
      return buffer.toString();
    } else {
      // 2 desimal
      final parts = amount.toStringAsFixed(info.decimals).split('.');
      final intPart = parts[0];
      final decPart = parts[1];

      final buffer = StringBuffer();
      for (var i = 0; i < intPart.length; i++) {
        buffer.write(intPart[i]);
        final rem = intPart.length - i - 1;
        if (rem > 0 && rem % 3 == 0) {
          buffer.write(',');
        }
      }
      return '${buffer.toString()}.$decPart';
    }
  }

  /// Format lengkap dengan simbol mata uang: e.g. "Rp 350.000", "$ 21.70", "€ 20.30", "¥ 3,290".
  static String formatMoney(num amount, String currencyCode) {
    final info = supportedCurrencies[currencyCode] ?? supportedCurrencies['IDR']!;
    final formatted = formatAmount(amount, currencyCode);
    if (currencyCode == 'IDR') {
      return '${info.symbol} $formatted';
    }
    return '${info.symbol} $formatted';
  }

  /// Konversi dan format dari basis IDR ke mata uang aktif atau mata uang pilihan.
  static String formatConverted(num idrAmount, {String? targetCurrency, double? customRate}) {
    final curr = targetCurrency ?? activeCurrency.value;
    if (curr == 'IDR') {
      return formatMoney(idrAmount, 'IDR');
    }
    final converted = convertFromIdr(idrAmount, curr, customRate: customRate);
    return formatMoney(converted, curr);
  }

  /// Tampilkan keterangan kurs (misal: "1 USD ≈ Rp 16.129 (1 IDR = 0.000062 USD)").
  static String formatRateDescription(String currencyCode, {double? customRate}) {
    if (currencyCode == 'IDR') return 'Mata uang dasar (1 IDR = 1 IDR)';
    final rate = customRate ?? getRate(currencyCode);
    if (rate <= 0) return '-';
    final idrPerUnit = (1.0 / rate).round();
    final idrFormatted = formatAmount(idrPerUnit, 'IDR');
    return '1 $currencyCode ≈ Rp $idrFormatted  (1 IDR = ${rate.toStringAsFixed(6)} $currencyCode)';
  }
}
