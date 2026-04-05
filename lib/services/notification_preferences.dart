import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  NotificationPreferences._();
  static NotificationPreferences? _instance;
  static NotificationPreferences get instance => _instance ??= NotificationPreferences._();

  static const _keyMatches = 'notif_matches';
  static const _keyMessages = 'notif_messages';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _storage async => _prefs ??= await SharedPreferences.getInstance();

  Future<bool> get matchNotifications async {
    return (await _storage).getBool(_keyMatches) ?? true;
  }

  Future<void> setMatchNotifications(bool value) async {
    await (await _storage).setBool(_keyMatches, value);
  }

  Future<bool> get messageNotifications async {
    return (await _storage).getBool(_keyMessages) ?? true;
  }

  Future<void> setMessageNotifications(bool value) async {
    await (await _storage).setBool(_keyMessages, value);
  }
}
