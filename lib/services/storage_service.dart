import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyHost = 'host';
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';

  Future<void> saveCredentials(
    String host,
    String username,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
  }

  Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'host': prefs.getString(_keyHost),
      'username': prefs.getString(_keyUsername),
      'password': prefs.getString(_keyPassword),
    };
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
  }
}
