import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import '../models/user_info.dart';
import '../models/category.dart';
import '../models/stream_item.dart';
import 'database_service.dart';

class XtreamService {
  final Map<String, String> _headers = {'User-Agent': 'IPTVSmarters'};

  String _ensureHttp(String host) {
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
      return 'http://$host';
    }
    return host;
  }

  Future<UserInfo?> authenticate(
    String host,
    String username,
    String password,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    }
    return null;
  }

  // Live TV
  Future<List<Category>> getLiveCategories(
    String host,
    String username,
    String password,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password&action=get_live_categories',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Category.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<StreamItem>> getLiveStreams(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    final formattedHost = _ensureHttp(host);
    var urlString =
        '$formattedHost/player_api.php?username=$username&password=$password&action=get_live_streams';
    if (categoryId != null) urlString += '&category_id=$categoryId';
    try {
      final response = await http
          .get(Uri.parse(urlString), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((json) => StreamItem.fromJson(json, type: ContentType.live))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // VOD (Movies)
  Future<List<Category>> getVodCategories(
    String host,
    String username,
    String password,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password&action=get_vod_categories',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Category.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<StreamItem>> getVodStreams(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    final formattedHost = _ensureHttp(host);
    var urlString =
        '$formattedHost/player_api.php?username=$username&password=$password&action=get_vod_streams';
    if (categoryId != null) urlString += '&category_id=$categoryId';
    try {
      final response = await http
          .get(Uri.parse(urlString), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((json) => StreamItem.fromJson(json, type: ContentType.movie))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // Series
  Future<List<Category>> getSeriesCategories(
    String host,
    String username,
    String password,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password&action=get_series_categories',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => Category.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<StreamItem>> getSeries(
    String host,
    String username,
    String password, {
    String? categoryId,
  }) async {
    final formattedHost = _ensureHttp(host);
    var urlString =
        '$formattedHost/player_api.php?username=$username&password=$password&action=get_series';
    if (categoryId != null) urlString += '&category_id=$categoryId';
    try {
      final response = await http
          .get(Uri.parse(urlString), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((json) => StreamItem.fromJson(json, type: ContentType.series))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getSeriesInfo(
    String host,
    String username,
    String password,
    String seriesId,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getVodInfo(
    String host,
    String username,
    String password,
    String vodId,
  ) async {
    final formattedHost = _ensureHttp(host);
    final url = Uri.parse(
      '$formattedHost/player_api.php?username=$username&password=$password&action=get_vod_info&vod_id=$vodId',
    );
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {}
    return null;
  }

  // --- Sync Logic ---

  Future<void> syncAllContent(
    String host,
    String username,
    String password,
    DatabaseService dbService, {
    Function(double)? onProgress,
  }) async {
    // 3 categories, each 33%
    await _syncCategory(host, username, password, dbService, ContentType.live);
    onProgress?.call(0.33);

    await _syncCategory(host, username, password, dbService, ContentType.movie);
    onProgress?.call(0.66);

    await _syncCategory(
      host,
      username,
      password,
      dbService,
      ContentType.series,
    );
    onProgress?.call(1.0);
  }

  Future<void> _syncCategory(
    String host,
    String username,
    String password,
    DatabaseService dbService,
    ContentType type,
  ) async {
    List<StreamItem> items = [];
    final typeStr = type.toString().split('.').last;

    switch (type) {
      case ContentType.live:
        items = await getLiveStreams(host, username, password);
        break;
      case ContentType.movie:
        items = await getVodStreams(host, username, password);
        break;
      case ContentType.series:
        items = await getSeries(host, username, password);
        break;
    }

    if (items.isNotEmpty) {
      await dbService.upsertContent(items);
      // Clean up items that were removed from server
      final activeIds = items.map((e) => e.streamId).toList();
      await dbService.deleteRemovedContent(activeIds, typeStr);
    }
  }

  String buildStreamUrl(
    String host,
    String username,
    String password,
    String streamId,
  ) {
    final formattedHost = _ensureHttp(host);
    return '$formattedHost/live/$username/$password/$streamId.ts';
  }

  String buildMovieUrl(
    String host,
    String username,
    String password,
    String streamId, {
    String container = 'mp4',
  }) {
    final formattedHost = _ensureHttp(host);
    return '$formattedHost/movie/$username/$password/$streamId.$container';
  }

  String buildSeriesUrl(
    String host,
    String username,
    String password,
    String streamId,
    String container,
  ) {
    final formattedHost = _ensureHttp(host);
    return '$formattedHost/series/$username/$password/$streamId.$container';
  }
}
