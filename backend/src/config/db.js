import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { env } from './env.js';

function bindValues(values) {
  return values.map((value) => (value instanceof Date ? value.toISOString() : value));
}

class SqliteDatabase {
  constructor(filename) {
    mkdirSync(path.dirname(filename), { recursive: true });
    this.database = new DatabaseSync(filename);
    this.database.exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  }

  async execute(sql, values = []) {
    const statement = this.database.prepare(sql);
    const parameters = bindValues(values);
    if (/^\s*(SELECT|WITH|PRAGMA)\b/i.test(sql)) {
      return [statement.all(...parameters), undefined];
    }
    const result = statement.run(...parameters);
    return [{
      affectedRows: Number(result.changes),
      insertId: Number(result.lastInsertRowid),
    }, undefined];
  }

  query(sql, values = []) {
    return this.execute(sql, values);
  }

  async getConnection() {
    return this;
  }

  release() {}

  async beginTransaction() {
    this.database.exec('BEGIN IMMEDIATE');
  }

  async commit() {
    this.database.exec('COMMIT');
  }

  async rollback() {
    this.database.exec('ROLLBACK');
  }

  async end() {
    this.database.close();
  }
}

export const pool = new SqliteDatabase(env.dbPath);

export async function withTransaction(callback) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
