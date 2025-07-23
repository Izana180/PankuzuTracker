import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'tracker.db');

    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT,
          latitude REAL,
          longitude REAL,
          motion_state TEXT
        )
      ''');
    });
  }

  Future<void> insertLog({
    required String timestamp,
    required double latitude,
    required double longitude,
    required String motionState,
  }) async {
    final dbClient = await db;
    await dbClient.insert('logs', {
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'motion_state': motionState,
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final dbClient = await db;
    return await dbClient.query('logs', orderBy: 'id DESC');
  }
}
