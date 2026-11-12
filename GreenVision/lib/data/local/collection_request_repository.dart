import 'package:sqflite/sqflite.dart';
import 'package:waste_classification/data/local/database_provider.dart';
import 'package:waste_classification/data/models/collection_request.dart';

class CollectionRequestRepository {
  CollectionRequestRepository._();
  static final CollectionRequestRepository instance =
      CollectionRequestRepository._();

  Future<void> insert(CollectionRequest req) async {
    final db = await DatabaseProvider.instance.database;
    await db.insert(
      'collection_requests',
      req.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CollectionRequest>> getAll() async {
    final db = await DatabaseProvider.instance.database;
    final rows = await db.query(
      'collection_requests',
      orderBy: 'created_at DESC',
    );
    return rows.map(CollectionRequest.fromMap).toList();
  }

  /// Accepts a collection request and links it to the accepting user.
  Future<void> acceptRequest({
    required String id,
    required int userId,
    required String userName,
  }) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      'collection_requests',
      {
        'status': RequestStatus.accepted.name,
        'accepted_by_user_id': userId,
        'accepted_by_user_name': userName,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Confirms and completes an accepted collection request.
  Future<void> completeRequest(String id) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      'collection_requests',
      {'status': RequestStatus.completed.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cancels a collection request (resets or cancels).
  Future<void> cancelRequest(String id) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      'collection_requests',
      {'status': RequestStatus.cancelled.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStatus(String id, RequestStatus status) async {
    final db = await DatabaseProvider.instance.database;
    await db.update(
      'collection_requests',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await DatabaseProvider.instance.database;
    await db.delete('collection_requests', where: 'id = ?', whereArgs: [id]);
  }
}
