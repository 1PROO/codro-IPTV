import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/stream_item.dart';
import '../services/xtream_service.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IptvProvider with ChangeNotifier {
  final XtreamService _xtreamService = XtreamService();
  final DatabaseService _dbService = DatabaseService();

  // Data
  List<Category> _liveCategories = [];
  List<StreamItem> _liveStreams = [];

  List<Category> _vodCategories = [];
  List<StreamItem> _vodStreams = [];

  List<Category> _seriesCategories = [];
  List<StreamItem> _seriesItems = [];

  // Data for Dashboard Carousels
  List<StreamItem> _dashboardLive = [];
  List<StreamItem> _dashboardMovies = [];
  List<StreamItem> _dashboardSeries = [];

  // Loading States
  bool _isLoadingLive = false;
  bool _isLoadingVod = false;
  bool _isLoadingSeries = false;
  bool _isLoadingDashboard = false;
  bool _isSyncing = false;
  double _syncProgress = 0.0;

  bool get isSyncing => _isSyncing;
  double get syncProgress => _syncProgress;

  // Getters
  List<Category> get categories => _liveCategories;
  List<StreamItem> get streams => _liveStreams;

  List<Category> get vodCategories => _vodCategories;
  List<StreamItem> get vodStreams => _vodStreams;

  List<Category> get seriesCategories => _seriesCategories;
  List<StreamItem> get seriesItems => _seriesItems;

  List<StreamItem> get dashboardLive => _dashboardLive;
  List<StreamItem> get dashboardMovies => _dashboardMovies;
  List<StreamItem> get dashboardSeries => _dashboardSeries;

  bool get isLoadingLive => _isLoadingLive;
  bool get isLoadingVod => _isLoadingVod;
  bool get isLoadingSeries => _isLoadingSeries;
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingStreams => _isLoadingLive;

  // Fetch Live
  Future<void> fetchCategories(
    String host,
    String username,
    String password,
  ) async {
    _isLoadingLive = true;
    notifyListeners();
    _liveCategories = await _xtreamService.getLiveCategories(
      host,
      username,
      password,
    );
    _isLoadingLive = false;
    notifyListeners();
  }

  Future<void> fetchStreams(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    _isLoadingLive = true;
    _liveStreams = [];
    notifyListeners();
    _liveStreams = await _xtreamService.getLiveStreams(
      host,
      username,
      password,
      categoryId: categoryId,
    );
    _isLoadingLive = false;
    notifyListeners();
  }

  // Fetch VOD
  Future<void> fetchVodCategories(
    String host,
    String username,
    String password,
  ) async {
    _isLoadingVod = true;
    notifyListeners();
    _vodCategories = await _xtreamService.getVodCategories(
      host,
      username,
      password,
    );
    _isLoadingVod = false;
    notifyListeners();
  }

  Future<void> fetchVodStreams(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    _isLoadingVod = true;
    _vodStreams = [];
    notifyListeners();
    _vodStreams = await _xtreamService.getVodStreams(
      host,
      username,
      password,
      categoryId: categoryId,
    );
    _isLoadingVod = false;
    notifyListeners();
  }

  // Fetch Series
  Future<void> fetchSeriesCategories(
    String host,
    String username,
    String password,
  ) async {
    _isLoadingSeries = true;
    notifyListeners();
    _seriesCategories = await _xtreamService.getSeriesCategories(
      host,
      username,
      password,
    );
    _isLoadingSeries = false;
    notifyListeners();
  }

  Future<void> fetchSeries(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    _isLoadingSeries = true;
    _seriesItems = [];
    notifyListeners();
    _seriesItems = await _xtreamService.getSeries(
      host,
      username,
      password,
      categoryId: categoryId,
    );
    _isLoadingSeries = false;
    notifyListeners();
  }

  // Fetch Dashboard Data
  Future<void> fetchDashboardData(
    String host,
    String username,
    String password,
  ) async {
    _isLoadingDashboard = true;
    notifyListeners();

    // Fetch top 15 from each as sample
    final futures = await Future.wait([
      _xtreamService.getLiveStreams(host, username, password),
      _xtreamService.getVodStreams(host, username, password),
      _xtreamService.getSeries(host, username, password),
    ]);

    _dashboardLive = futures[0].take(15).toList();
    _dashboardMovies = futures[1].take(15).toList();
    _dashboardSeries = futures[2].take(15).toList();

    _isLoadingDashboard = false;
    notifyListeners();
  }

  // Smart Sync Trigger
  Future<void> triggerSmartSync(
    String host,
    String username,
    String password, {
    bool force = false,
  }) async {
    if (_isSyncing) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt('last_sync_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Sync every 24 hours unless forced or first time
    if (!force && now - lastSync < 24 * 60 * 60 * 1000 && lastSync != 0) {
      debugPrint('Sync skipped: Last sync was recent.');
      return;
    }

    _isSyncing = true;
    _syncProgress = 0.0;
    notifyListeners();

    try {
      await _xtreamService.syncAllContent(
        host,
        username,
        password,
        _dbService,
        onProgress: (p) {
          _syncProgress = p;
          notifyListeners();
        },
      );
      await prefs.setInt('last_sync_timestamp', now);
      debugPrint('Smart Sync completed successfully.');
    } catch (e) {
      debugPrint('Smart Sync failed: $e');
    } finally {
      _isSyncing = false;
      _syncProgress = 1.0;
      notifyListeners();
    }
  }

  Future<List<StreamItem>> searchLocally(String query, {String? type}) async {
    // Primary source: Database
    final dbResults = await _dbService.searchContent(query, type: type);
    if (dbResults.isNotEmpty) return dbResults;

    // Fallback: In-memory (useful if sync hasn't finished)
    final List<StreamItem> allItems = [
      ..._dashboardLive,
      ..._dashboardMovies,
      ..._dashboardSeries,
      ..._liveStreams,
      ..._vodStreams,
      ..._seriesItems,
    ];

    final lowercaseQuery = query.toLowerCase().trim();
    return allItems
        .where((item) {
          final matchesQuery = item.name.toLowerCase().contains(lowercaseQuery);
          if (type != null) {
            final typeMatches =
                item.contentType.toString().split('.').last == type;
            return matchesQuery && typeMatches;
          }
          return matchesQuery;
        })
        .take(20)
        .toList();
  }

  // Favorite methods
  Future<void> toggleFavorite(StreamItem item) async {
    await _dbService.toggleFavorite(item);
    notifyListeners();
  }

  Future<bool> isFavorite(String streamId) async {
    return await _dbService.isFavorite(streamId);
  }

  Future<List<StreamItem>> getFavorites() async {
    return await _dbService.getFavorites();
  }

  Future<Map<String, dynamic>?> getSeriesInfo(
    String host,
    String username,
    String password,
    String seriesId,
  ) async {
    return await _xtreamService.getSeriesInfo(
      host,
      username,
      password,
      seriesId,
    );
  }

  Future<Map<String, dynamic>?> getVodInfo(
    String host,
    String username,
    String password,
    String vodId,
  ) async {
    return await _xtreamService.getVodInfo(host, username, password, vodId);
  }
}
