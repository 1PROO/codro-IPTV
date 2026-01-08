import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/stream_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'codro_iptv.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE favorites (
          stream_id TEXT PRIMARY KEY,
          name TEXT,
          icon TEXT,
          type TEXT,
          container TEXT
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Standard table for all content for quick lookups and sync
    await db.execute('''
      CREATE TABLE content (
        id TEXT PRIMARY KEY,
        name TEXT,
        icon TEXT,
        category_id TEXT,
        container TEXT,
        type TEXT,
        last_updated INTEGER
      )
    ''');

    // FTS5 table for fast searching
    await db.execute('''
      CREATE VIRTUAL TABLE content_search USING fts5(
        id UNINDEXED,
        name,
        type UNINDEXED,
        tokenize='unicode61'
      )
    ''');

    // Indexing for category filtering
    await db.execute(
      'CREATE INDEX idx_content_type_cat ON content (type, category_id)',
    );

    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        stream_id TEXT PRIMARY KEY,
        name TEXT,
        icon TEXT,
        type TEXT,
        container TEXT
      )
    ''');
  }

  Future<void> upsertContent(List<StreamItem> items) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var item in items) {
      final typeStr = item.contentType.toString().split('.').last;

      batch.insert('content', {
        'id': item.streamId,
        'name': item.name,
        'icon': item.streamIcon,
        'category_id': item.categoryId,
        'container': item.containerExtension,
        'type': typeStr,
        'last_updated': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Upsert into FTS table (delete then insert for standard FTS update)
      batch.delete(
        'content_search',
        where: 'id = ?',
        whereArgs: [item.streamId],
      );
      batch.insert('content_search', {
        'id': item.streamId,
        'name': item.name,
        'type': typeStr,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<StreamItem>> searchContent(String query, {String? type}) async {
    final db = await database;

    String sql = '''
      SELECT c.* FROM content c
      JOIN content_search cs ON c.id = cs.id
      WHERE content_search MATCH ?
    ''';

    List<dynamic> args = ['$query*'];

    if (type != null) {
      sql += ' AND c.type = ?';
      args.add(type);
    }

    sql += ' ORDER BY rank LIMIT 50';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);

    return List.generate(maps.length, (i) {
      return StreamItem(
        num: 0,
        name: maps[i]['name'],
        streamId: maps[i]['id'],
        streamIcon: maps[i]['icon'],
        categoryId: maps[i]['category_id'],
        containerExtension: maps[i]['container'],
        contentType: _parseType(maps[i]['type']),
      );
    });
  }

  Future<void> deleteRemovedContent(List<String> activeIds, String type) async {
    final db = await database;
    if (activeIds.isEmpty) return;

    final idList = activeIds.map((id) => "'$id'").join(',');

    await db.transaction((txn) async {
      await txn.delete(
        'content',
        where: 'type = ? AND id NOT IN ($idList)',
        whereArgs: [type],
      );
      await txn.delete(
        'content_search',
        where: 'type = ? AND id NOT IN ($idList)',
        whereArgs: [type],
      );
    });
  }

  Future<void> toggleFavorite(StreamItem item) async {
    final db = await database;
    final exists = await isFavorite(item.streamId);

    if (exists) {
      await db.delete(
        'favorites',
        where: 'stream_id = ?',
        whereArgs: [item.streamId],
      );
    } else {
      await db.insert('favorites', {
        'stream_id': item.streamId,
        'name': item.name,
        'icon': item.streamIcon,
        'type': item.contentType.toString().split('.').last,
        'container': item.containerExtension,
      });
    }
  }

  Future<bool> isFavorite(String streamId) async {
    final db = await database;
    final res = await db.query(
      'favorites',
      where: 'stream_id = ?',
      whereArgs: [streamId],
    );
    return res.isNotEmpty;
  }

  Future<List<StreamItem>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorites');

    return List.generate(maps.length, (i) {
      return StreamItem(
        num: 0,
        name: maps[i]['name'],
        streamId: maps[i]['stream_id'],
        streamIcon: maps[i]['icon'],
        categoryId: '',
        containerExtension: maps[i]['container'],
        contentType: _parseType(maps[i]['type']),
      );
    });
  }

  ContentType _parseType(String type) {
    switch (type) {
      case 'live':
        return ContentType.live;
      case 'movie':
        return ContentType.movie;
      case 'series':
        return ContentType.series;
      default:
        return ContentType.live;
    }
  }
}
