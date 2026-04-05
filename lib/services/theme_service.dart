import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'themeMode';

  final ValueNotifier<ThemeMode> _notifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  ValueNotifier<ThemeMode> get notifier => _notifier;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case 'light':
        _notifier.value = ThemeMode.light;
        break;
      case 'system':
        _notifier.value = ThemeMode.system;
        break;
      default:
        _notifier.value = ThemeMode.dark;
    }
  }

  Future<void> toggleDarkLight() async {
    final prefs = await SharedPreferences.getInstance();
    final next =
        _notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _notifier.value = next;
    await prefs.setString(_key, next == ThemeMode.light ? 'light' : 'dark');
  }
}

