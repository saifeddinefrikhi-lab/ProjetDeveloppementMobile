import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:waste_classification/data/local/database_provider.dart';
import 'package:waste_classification/data/models/user_model.dart';

/// Simple SHA-256 hash — passwords are never stored in plaintext.
String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

class UserRepository {
  Future<Database> get _db => DatabaseProvider.instance.database;

  /// Register a new user. Returns the created [UserModel] or throws on duplicate email.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await _db;

    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (existing.isNotEmpty) {
      throw Exception('email_already_exists');
    }

    final now = DateTime.now().toIso8601String();
    final user = UserModel(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: _hashPassword(password),
      createdAt: now,
    );

    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  /// Login. Returns the [UserModel] if credentials match, otherwise throws.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) throw Exception('user_not_found');

    final user = UserModel.fromMap(rows.first);
    if (user.passwordHash != _hashPassword(password)) {
      throw Exception('invalid_password');
    }
    return user;
  }

  /// Update profile fields (name, avatarInitials, optionally password).
  Future<UserModel> updateProfile({
    required int userId,
    required String name,
    String? currentPassword,
    String? newPassword,
    String? avatarInitials,
  }) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) throw Exception('user_not_found');
    final user = UserModel.fromMap(rows.first);

    final Map<String, dynamic> values = {
      'name': name.trim(),
      'avatar_initials': avatarInitials,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        if (user.passwordHash != _hashPassword(currentPassword)) {
          throw Exception('invalid_current_password');
        }
      }
      values['password_hash'] = _hashPassword(newPassword);
    }

    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);

    final updatedRows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return UserModel.fromMap(updatedRows.first);
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }
}

final userRepository = UserRepository();
