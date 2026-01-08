import 'package:flutter/material.dart';
import '../models/user_info.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../services/appwrite_service.dart';

class AuthProvider with ChangeNotifier {
  final XtreamService _xtreamService = XtreamService();
  final StorageService _storageService = StorageService();
  final AppwriteService _appwriteService = AppwriteService();

  UserInfo? _userInfo;
  String? _host;
  String? _username;
  String? _password;
  bool _isLoading = false;
  String? _loginError;

  UserInfo? get userInfo => _userInfo;
  String? get host => _host;
  String? get username => _username;
  String? get password => _password;
  bool get isLoading => _isLoading;
  String? get loginError => _loginError;
  bool get isAuthenticated => _userInfo != null && _userInfo!.auth;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _loginError = null;
    notifyListeners();

    try {
      // 1. Authenticate with Appwrite/Database
      final appUser = await _appwriteService.authenticateUser(
        username.trim(),
        password.trim(),
      );

      if (appUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (appUser['error'] == 'expired') {
        _loginError = 'expired';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Get server credentials from the database record
      final String host = appUser['host'] ?? '';
      final String serverUser = appUser['server_username'] ?? '';
      final String serverPass = appUser['server_password'] ?? '';

      // 3. Authenticate with IPTV Service
      final userInfo = await _xtreamService.authenticate(
        host,
        serverUser,
        serverPass,
      );

      _isLoading = false;

      if (userInfo != null && userInfo.auth) {
        _userInfo = userInfo;
        _host = host;
        _username = serverUser; // We store the server username for IPTV calls
        _password = serverPass;

        // Save user's login credentials (not server) if we want to auto-login to Appwrite
        // OR save server credentials to skip Appwrite check on next launch (faster)
        // Let's save the original username/password for the auto-login flow
        await _storageService.saveCredentials(host, username, password);

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login Error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> tryAutoLogin() async {
    try {
      final creds = await _storageService.getCredentials();
      if (creds['username'] != null && creds['password'] != null) {
        // Here creds['username'] is the APP username
        await login(creds['username']!, creds['password']!);
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
    }
  }

  void logout() {
    _userInfo = null;
    _host = null;
    _username = null;
    _password = null;
    _storageService.clearCredentials();
    notifyListeners();
  }
}
