import fs from 'node:fs/promises';
import path from 'node:path';
import { env } from './env.js';
import { pool } from './db.js';

await fs.mkdir(path.dirname(env.dbPath), { recursive: true });

const sql = await fs.readFile(new URL('./schema.sql', import.meta.url), 'utf8');
for (const statement of sql.split(';').map((part) => part.trim()).filter(Boolean)) await pool.query(statement);
console.log('Database migration completed.');
await pool.end();
