import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  final _secureStorage = const FlutterSecureStorage();

  bool _notificationsEnabled = true;
  String _themeMode = 'System'; // 'Light', 'Dark', 'System'
  String _language = 'English';
  bool _appLockEnabled = false;

  bool get notificationsEnabled => _notificationsEnabled;
  String get themeModeString => _themeMode;
  ThemeMode get themeMode {
    switch (_themeMode) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System':
      default:
        return ThemeMode.system;
    }
  }
  String get language => _language;
  bool get appLockEnabled => _appLockEnabled;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    _notificationsEnabled = _prefs?.getBool('notifications') ?? true;
    _themeMode = _prefs?.getString('theme') ?? 'System';
    _language = _prefs?.getString('language') ?? 'English';
    _appLockEnabled = _prefs?.getBool('appLock') ?? false;

    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    await _prefs?.setBool('notifications', value);
    notifyListeners();
  }

  Future<void> setTheme(String value) async {
    _themeMode = value;
    await _prefs?.setString('theme', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs?.setString('language', value);
    notifyListeners();
  }

  Future<void> setAppLock(bool value) async {
    _appLockEnabled = value;
    await _prefs?.setBool('appLock', value);
    
    if (!value) {
      await clearSecurePin();
    }
    
    notifyListeners();
  }

  // Secure PIN methods for Biometric login
  Future<void> saveSecurePin(String pin) async {
    await _secureStorage.write(key: 'user_pin', value: pin);
  }

  Future<String?> getSecurePin() async {
    return await _secureStorage.read(key: 'user_pin');
  }

  Future<void> clearSecurePin() async {
    await _secureStorage.delete(key: 'user_pin');
  }
}
