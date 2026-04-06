import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/crash_event.dart';

class DatabaseService {
  static Database? _database;
  static const String tableName = 'crashes';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'impact_node.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rider_id TEXT,
            timestamp TEXT,
            latitude REAL,
            longitude REAL,
            speed_kmph REAL,
            sos_sent INTEGER,
            sos_cancelled INTEGER,
            g_force_peak REAL,
            tilt_angle REAL,
            gyroscope_peak REAL,
            speed_before REAL,
            speed_after REAL,
            impact_duration_ms INTEGER,
            false_positive INTEGER,
            is_near_miss INTEGER
          )
        ''');
      },
    );
  }

  static Future<void> insertCrash(CrashEvent crash) async {
    final db = await database;
    final data = crash.toJson();
    // Convert booleans to INTEGER for SQLite
    data['sos_sent'] = data['sos_sent'] == true ? 1 : 0;
    data['sos_cancelled'] = data['sos_cancelled'] == true ? 1 : 0;
    data['false_positive'] = data['false_positive'] == true ? 1 : 0;
    data['is_near_miss'] = data['is_near_miss'] == true ? 1 : 0;
    
    await db.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CrashEvent>> getAllCrashes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName, orderBy: 'timestamp DESC');

    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      // Convert SQLite INTEGERS back to booleans
      map['sos_sent'] = map['sos_sent'] == 1;
      map['sos_cancelled'] = map['sos_cancelled'] == 1;
      map['false_positive'] = map['false_positive'] == 1;
      map['is_near_miss'] = map['is_near_miss'] == 1;
      
      // Need ID as string conceptually
      map['id'] = map['id'].toString();
      
      return CrashEvent.fromJson(map);
    });
  }

  static Future<void> deleteCrash(String id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }
}
