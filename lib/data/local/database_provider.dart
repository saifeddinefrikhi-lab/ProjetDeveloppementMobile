import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton that owns and migrates the shared SQLite database.
/// Both [ScanRepository], [UserRepository], and [CollectionRequestRepository] obtain the DB from here.
class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider instance = DatabaseProvider._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = p.join(await getDatabasesPath(), 'waste_classification.db');
    debugPrint('╔══════════════════════════════════════════════════════╗');
    debugPrint('║  SQLite DB PATH (open with DB Browser for SQLite):   ║');
    debugPrint('║  $dbPath');
    debugPrint('╚══════════════════════════════════════════════════════╝');
    _database = await openDatabase(
      dbPath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Defensive migration to guarantee all columns exist without data loss
        try {
          await db.execute('ALTER TABLE scan_results ADD COLUMN user_id INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN latitude REAL');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN longitude REAL');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN creator_id INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN creator_name TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN accepted_by_user_id INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE collection_requests ADD COLUMN accepted_by_user_name TEXT');
        } catch (_) {}
      },
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_results (
        id TEXT PRIMARY KEY,
        image_path TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        category_id TEXT NOT NULL,
        model_label TEXT NOT NULL,
        confidence REAL NOT NULL,
        user_id INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_results_scanned_at '
      'ON scan_results(scanned_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_results_category_id '
      'ON scan_results(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scan_results_user_id '
      'ON scan_results(user_id)',
    );
    await _createUsersTable(db);
    await _createCollectionRequestsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUsersTable(db);
    }
    if (oldVersion < 3) {
      await _createCollectionRequestsTable(db);
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN latitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN longitude REAL');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE scan_results ADD COLUMN user_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scan_results_user_id ON scan_results(user_id)');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN creator_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN creator_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN accepted_by_user_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE collection_requests ADD COLUMN accepted_by_user_name TEXT');
      } catch (_) {}
    }
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        avatar_initials TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)',
    );
  }

  Future<void> _createCollectionRequestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collection_requests (
        id TEXT PRIMARY KEY,
        address TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        waste_types TEXT NOT NULL,
        notes TEXT,
        requested_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        creator_id INTEGER,
        creator_name TEXT,
        accepted_by_user_id INTEGER,
        accepted_by_user_name TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_collection_requests_status '
      'ON collection_requests(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_collection_requests_creator '
      'ON collection_requests(creator_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_collection_requests_accepted '
      'ON collection_requests(accepted_by_user_id)',
    );
  }
}
