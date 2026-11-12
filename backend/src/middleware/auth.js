import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { pool } from '../config/db.js';

export async function requireAuth(req, _res, next) {
  const header = req.get('authorization');
  if (!header?.startsWith('Bearer ')) {
    const error = new Error('Authentication required'); error.status = 401; return next(error);
  }
  try {
    const payload = jwt.verify(header.slice(7), env.jwtSecret);
    const [rows] = await pool.execute('SELECT id, name, email, role, avatar_initials, avatar_url, created_at, updated_at FROM users WHERE id = ?', [payload.sub]);
    if (!rows[0]) { const error = new Error('User no longer exists'); error.status = 401; return next(error); }
    req.user = rows[0];
    next();
  } catch (error) {
    error.status = 401;
    error.message = 'Invalid or expired token';
    next(error);
  }
}

export function requireRole(...roles) {
  return (req, _res, next) => {
    if (roles.includes(req.user?.role)) return next();
    const error = new Error('Insufficient permissions');
    error.status = 403;
    return next(error);
  };
}
