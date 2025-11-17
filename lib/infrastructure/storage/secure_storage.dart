import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_logger.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Secure Storage (for sensitive data like tokens)
  Future<void> writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e, stack) {
      AppLogger.error('Failed to write secure data', e, stack);
    }
  }

  Future<String?> readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e, stack) {
      AppLogger.error('Failed to read secure data', e, stack);
      return null;
    }
  }

  Future<void> deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e, stack) {
      AppLogger.error('Failed to delete secure data', e, stack);
    }
  }

  // Regular Storage (for non-sensitive data)
  Future<void> write(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? read(String key) {
    return _prefs?.getString(key);
  }

  Future<void> writeBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? readBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<void> delete(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
    await _secureStorage.deleteAll();
  }
}