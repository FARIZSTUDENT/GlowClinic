import 'package:flutter_test/flutter_test.dart';
import 'package:glowclinic/core/currency.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CurrencyService & Rate Conversion Tests', () {
    test('Fallback rates exist for all supported currencies', () {
      expect(kFallbackRates.containsKey('USD'), isTrue);
      expect(kFallbackRates.containsKey('EUR'), isTrue);
      expect(kFallbackRates.containsKey('JPY'), isTrue);
      expect(kFallbackRates['USD']! > 0, isTrue);
    });

    test('IDR base conversion returns exact same amount', () {
      const amountIdr = 250000.0;
      final converted = CurrencyService.convertFromIdr(amountIdr, 'IDR');
      expect(converted, equals(250000.0));
      expect(CurrencyService.formatMoney(converted, 'IDR'), contains('Rp'));
    });

    test('Conversion to USD uses target-per-IDR multiplier correctly', () {
      const amountIdr = 1000000.0;
      final usdRate = CurrencyService.getRate('USD');
      final expectedUsd = amountIdr * usdRate;
      final converted = CurrencyService.convertFromIdr(amountIdr, 'USD');

      expect(converted, equals(expectedUsd));
      final formatted = CurrencyService.formatMoney(converted, 'USD');
      expect(formatted, startsWith('\$'));
    });

    test('Multiple currency switches do not suffer from re-conversion drift', () {
      const baseIdr = 500000.0;

      // Switch to USD
      final usd1 = CurrencyService.convertFromIdr(baseIdr, 'USD');
      // Switch to JPY
      final jpy = CurrencyService.convertFromIdr(baseIdr, 'JPY');
      // Switch to EUR
      final eur = CurrencyService.convertFromIdr(baseIdr, 'EUR');
      // Switch back to USD
      final usd2 = CurrencyService.convertFromIdr(baseIdr, 'USD');

      // usd1 and usd2 must be strictly identical because conversion always originates from baseIdr
      expect(usd1, equals(usd2));
      expect(jpy, equals(baseIdr * CurrencyService.getRate('JPY')));
      expect(eur, equals(baseIdr * CurrencyService.getRate('EUR')));
    });

    test('Fallback handling when currency is unknown', () {
      const amountIdr = 150000.0;
      // Unknown currency should safely default to 1.0 multiplier and not crash
      final rate = CurrencyService.getRate('XYZ');
      expect(rate, equals(1.0));
      final converted = CurrencyService.convertFromIdr(amountIdr, 'XYZ');
      expect(converted, equals(amountIdr));
    });

    test('Rate description formatting', () {
      final descIdr = CurrencyService.formatRateDescription('IDR');
      expect(descIdr, contains('Mata uang dasar'));

      final descUsd = CurrencyService.formatRateDescription('USD');
      expect(descUsd, contains('1 USD ≈ Rp'));
      expect(descUsd, contains('1 IDR ='));
    });

    test('formatConverted helper returns formatted symbol and amount', () {
      const amountIdr = 500000.0;
      final textUsd = CurrencyService.formatConverted(amountIdr, targetCurrency: 'USD');
      expect(textUsd, startsWith('\$'));

      final textIdr = CurrencyService.formatConverted(amountIdr, targetCurrency: 'IDR');
      expect(textIdr, startsWith('Rp'));
      expect(textIdr, contains('500.000'));
    });
  });
}
