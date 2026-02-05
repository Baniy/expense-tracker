import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool isDark;
  final String currency;

  SettingsState({required this.isDark, required this.currency});

  SettingsState copyWith({bool? isDark, String? currency}) => SettingsState(
        isDark: isDark ?? this.isDark,
        currency: currency ?? this.currency,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _keyIsDark = 'isDark';
  static const _keyCurrency = 'currency';

  SettingsNotifier() : super(SettingsState(isDark: false, currency: 'BDT')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_keyIsDark) ?? false;
    final currency = prefs.getString(_keyCurrency) ?? 'BDT';
    state = SettingsState(isDark: isDark, currency: currency);
  }

  Future<void> setDark(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDark, dark);
    state = state.copyWith(isDark: dark);
  }

  Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, currency);
    state = state.copyWith(currency: currency);
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) => SettingsNotifier());
