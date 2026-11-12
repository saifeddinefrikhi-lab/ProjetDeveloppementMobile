import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:waste_classification/data/local/database_provider.dart';
import 'package:waste_classification/data/models/scan_result.dart';

/// Scan history repository — uses the shared [DatabaseProvider] database.
class ScanRepository {
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<Database> get _db => DatabaseProvider.instance.database;

  Future<void> insert(ScanResult result) async {
    final db = await _db;
    await db.insert(
      'scan_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    revision.value++;
  }

  Future<List<ScanResult>> getAll() async {
    final db = await _db;
    final rows = await db.query('scan_results', orderBy: 'scanned_at DESC');
    return rows.map(ScanResult.fromMap).toList(growable: false);
  }

  /// Returns scan history for a specific user.
  /// If [userId] is null, returns scans done without being logged in.
  Future<List<ScanResult>> getByUser(int? userId) async {
    final db = await _db;
    final List<Map<String, dynamic>> rows;
    if (userId != null) {
      rows = await db.query(
        'scan_results',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'scanned_at DESC',
      );
    } else {
      rows = await db.query(
        'scan_results',
        where: 'user_id IS NULL',
        orderBy: 'scanned_at DESC',
      );
    }
    return rows.map(ScanResult.fromMap).toList(growable: false);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('scan_results', where: 'id = ?', whereArgs: [id]);
    revision.value++;
  }
}

final scanRepository = ScanRepository();
