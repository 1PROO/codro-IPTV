import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

class AppwriteService {
  static const String endpoint =
      'https://fra.cloud.appwrite.io/v1'; // From screenshot
  static const String projectId = '695b7069000ea8ac5117';
  static const String databaseId = '695b754f0033df207fa8';
  static const String logosCollectionId = 'channel_logos';
  static const String usersCollectionId = 'users';
  static const String configCollectionId = 'config';

  final Client _client;
  late final Databases _databases;

  AppwriteService() : _client = Client() {
    _client.setEndpoint(endpoint).setProject(projectId);
    _databases = Databases(_client);
  }

  // --- Logo Methods ---
  final Map<String, String> _logoCache = {};

  Future<void> loadLogoMappings() async {
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: logosCollectionId,
      );

      for (var doc in result.documents) {
        final data = doc.data;
        if (data.containsKey('channelId') && data.containsKey('url')) {
          final key = data['channelId'].toString().toLowerCase().trim();
          _logoCache[key] = data['url'].toString();
        }
      }
    } catch (e) {
      debugPrint('Appwrite Load Logos Error: $e');
    }
  }

  String? getHqLogo(String channelName) {
    return _logoCache[channelName.toLowerCase().trim()];
  }

  // --- Config/Flags Methods ---
  Future<Map<String, dynamic>> getConfig() async {
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: configCollectionId,
      );

      final Map<String, dynamic> config = {};
      for (var doc in result.documents) {
        config[doc.data['key']] = doc.data['value'];
      }
      return config;
    } catch (e) {
      debugPrint('Appwrite Load Config Error: $e');
      return {};
    }
  }

  Future<bool> updateConfig(String key, dynamic value) async {
    try {
      // Find the document with this key
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: configCollectionId,
        queries: [Query.equal('key', key)],
      );

      if (result.documents.isNotEmpty) {
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: configCollectionId,
          documentId: result.documents.first.$id,
          data: {'value': value.toString()},
        );
      } else {
        await _databases.createDocument(
          databaseId: databaseId,
          collectionId: configCollectionId,
          documentId: ID.unique(),
          data: {'key': key, 'value': value.toString()},
        );
      }
      return true;
    } catch (e) {
      debugPrint('Appwrite Update Config Error: $e');
      return false;
    }
  }

  // --- User Methods ---
  Future<Map<String, dynamic>?> authenticateUser(
    String username,
    String password,
  ) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [
          Query.equal('username', username),
          Query.equal('password', password),
          Query.equal('is_active', true),
        ],
      );

      if (result.documents.isNotEmpty) {
        final userData = result.documents.first.data;

        // Expiry Check
        if (userData['exp_date'] != null &&
            userData['exp_date'].toString().isNotEmpty) {
          try {
            final expDate = DateTime.parse(userData['exp_date'].toString());
            if (DateTime.now().isAfter(expDate)) {
              return {'error': 'expired'};
            }
          } catch (e) {
            debugPrint('Expiry Date Parse Error: $e');
          }
        }

        return userData;
      }
      return null;
    } catch (e) {
      debugPrint('Appwrite Auth Error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    try {
      final result = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
      );
      return result.documents.map((d) => {'id': d.$id, ...d.data}).toList();
    } catch (e) {
      debugPrint('Appwrite List Users Error: $e');
      return [];
    }
  }

  Future<bool> updateUser(String documentId, Map<String, dynamic> data) async {
    try {
      await _databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: documentId,
        data: data,
      );
      return true;
    } catch (e) {
      debugPrint('Appwrite Update User Error: $e');
      return false;
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      await _databases.createDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: ID.unique(),
        data: data,
      );
      return true;
    } catch (e) {
      debugPrint('Appwrite Create User Error: $e');
      return false;
    }
  }
}
