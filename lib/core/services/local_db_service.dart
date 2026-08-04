import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static late Database _db;
  static const String _apiCacheTable = 'api_cache';
  static const String _syncQueueTable = 'sync_queue';

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'abhaya_local.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_apiCacheTable (
            endpoint TEXT PRIMARY KEY,
            data TEXT,
            timestamp INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE $_syncQueueTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            payload TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // --- API Cache (For GET requests) ---
  static Future<void> cacheGetResponse(String endpoint, dynamic data) async {
    await _db.insert(
      _apiCacheTable,
      {
        'endpoint': endpoint,
        'data': jsonEncode(data),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<dynamic> getCachedResponse(String endpoint) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      _apiCacheTable,
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );

    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['data'] as String);
    }
    return null;
  }

  // --- Offline Sync Queue ---
  static Future<void> enqueueRequest(String action, Map<String, dynamic> payload) async {
    await _db.insert(
      _syncQueueTable,
      {
        'action': action,
        'payload': jsonEncode(payload),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    return await _db.query(_syncQueueTable, orderBy: 'timestamp ASC');
  }

  static Future<void> removePendingRequest(int id) async {
    await _db.delete(_syncQueueTable, where: 'id = ?', whereArgs: [id]);
  }
}
