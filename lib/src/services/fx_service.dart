import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final fxServiceProvider = Provider<FxService>((ref) => FxService());

class FxService {
  static const _base = 'https://api.frankfurter.app';
  final Map<String, _CachedRates> _cache = {};

  Future<Map<String, double>> getRates(String baseCurrency) async {
    final cached = _cache[baseCurrency];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMinutes < 60) {
      return cached.rates;
    }
    try {
      final resp = await http
          .get(Uri.parse('$_base/latest?from=$baseCurrency'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rates = Map<String, double>.from(
          (data['rates'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        );
        rates[baseCurrency] = 1.0;
        _cache[baseCurrency] =
            _CachedRates(rates: rates, fetchedAt: DateTime.now());
        return rates;
      }
    } catch (_) {}
    // Fallback: identity mapping (no conversion available)
    return {baseCurrency: 1.0};
  }

  Future<double> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    final rates = await getRates(from);
    return amount * (rates[to] ?? 1.0);
  }

  /// Synchronous conversion using cached rates; returns null if not cached.
  double? convertSync(double amount, String from, String to) {
    if (from == to) return amount;
    final cached = _cache[from];
    if (cached == null) return null;
    final rate = cached.rates[to];
    if (rate == null) return null;
    return amount * rate;
  }

  DateTime? lastFetched(String baseCurrency) =>
      _cache[baseCurrency]?.fetchedAt;
}

class _CachedRates {
  final Map<String, double> rates;
  final DateTime fetchedAt;
  _CachedRates({required this.rates, required this.fetchedAt});
}
