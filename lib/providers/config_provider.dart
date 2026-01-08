import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';

class ConfigProvider with ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  // Feature flags
  bool isMaintenanceMode = false;
  bool forceUpdate = false;
  bool showAnnouncement = true;
  String announcement = '';
  String updateUrl = '';
  String primaryColor = '#FFFFFF';
  bool freeTrialMode = false;
  String streamingAgent = 'IPTVSmarters';
  String appodealKey =
      '0b5c0c469e1c01f1161f7aa8b5b6d08a25513d94e8f7a425'; // Default fallback

  ConfigProvider() {
    init();
  }

  Future<void> init() async {
    await refreshFlags();
  }

  Future<void> refreshFlags() async {
    final config = await _appwriteService.getConfig();

    isMaintenanceMode = config['isMaintenanceMode']?.toString() == 'true';
    forceUpdate = config['forceUpdate']?.toString() == 'true';
    showAnnouncement =
        config['show_announcement']?.toString() != 'false'; // Default to true
    announcement = config['app_announcement']?.toString() ?? '';
    updateUrl = config['update_url']?.toString() ?? '';
    primaryColor = config['app_primary_color']?.toString() ?? '#FFFFFF';
    freeTrialMode = config['free_trial_mode']?.toString() == 'true';
    streamingAgent = config['streaming_agent']?.toString() ?? 'IPTVSmarters';
    appodealKey =
        config['appodeal_key']?.toString() ??
        '0b5c0c469e1c01f1161f7aa8b5b6d08a25513d94e8f7a425';

    notifyListeners();
  }

  Future<bool> updateFlag(String key, dynamic value) async {
    final success = await _appwriteService.updateConfig(key, value);
    if (success) {
      await refreshFlags();
    }
    return success;
  }
}
