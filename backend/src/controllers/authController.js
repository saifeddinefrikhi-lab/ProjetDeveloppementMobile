import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';
import { sendPasswordResetEmail } from '../services/emailService.js';
import { ok, publicUser } from '../utils/response.js';
import { forgotPasswordSchema, loginSchema, profileSchema, registerSchema, resetPasswordSchema, validate, verifyResetCodeSchema } from '../utils/validation.js';

function tokenFor(user) { return jwt.sign({ sub: String(user.id), role: user.role }, env.jwtSecret, { expiresIn: env.jwtExpiresIn }); }
function initials(name) { return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase() || '?'; }

export async function register(req, res) {
  const input = validate(registerSchema, req.body);
  const password = await bcrypt.hash(input.password, 12);
  try {
    const [result] = await pool.execute('INSERT INTO users (name, email, password, avatar_initials) VALUES (?, ?, ?, ?)', [input.name, input.email, password, initials(input.name)]);
    const [rows] = await pool.execute('SELECT id, name, email, role, avatar_initials, avatar_url, created_at, updated_at FROM users WHERE id = ?', [result.insertId]);
    const user = rows[0];
    return ok(res, { user: publicUser(user) }, 201);
  } catch (error) { if (error.code === 'SQLITE_CONSTRAINT_UNIQUE' || error.code === 'SQLITE_CONSTRAINT') { error.status = 409; error.message = 'Email is already registered'; } throw error; }
}

export async function login(req, res) {
  const input = validate(loginSchema, req.body);
  const [rows] = await pool.execute('SELECT * FROM users WHERE email = ?', [input.email]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(input.password, user.password))) { const error = new Error('Invalid email or password'); error.status = 401; throw error; }
  return ok(res, { token: tokenFor(user), user: publicUser(user) });
}

export async function forgotPassword(req, res) {
  const input = validate(forgotPasswordSchema, req.body);
  const [rows] = await pool.execute('SELECT id FROM users WHERE email = ?', [input.email]);
  if (rows[0]) {
    const code = crypto.randomInt(100000, 1000000).toString();
    const tokenHash = crypto.createHash('sha256').update(code).digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    await pool.execute('DELETE FROM password_reset_tokens WHERE user_id = ?', [rows[0].id]);
    await pool.execute('INSERT INTO password_reset_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)', [tokenHash, rows[0].id, expiresAt]);
    await sendPasswordResetEmail(input.email, code);
  }
  return ok(res, { message: 'If an account exists for that email, a reset code has been sent.' });
}

export async function verifyResetCode(req, res) {
  const input = validate(verifyResetCodeSchema, req.body);
  const tokenHash = crypto.createHash('sha256').update(input.code).digest('hex');
  const [rows] = await pool.execute(
    "SELECT password_reset_tokens.user_id FROM password_reset_tokens INNER JOIN users ON users.id = password_reset_tokens.user_id WHERE users.email = ? AND password_reset_tokens.token_hash = ? AND password_reset_tokens.used_at IS NULL AND datetime(replace(password_reset_tokens.expires_at, 'T', ' ')) > datetime('now')",
    [input.email, tokenHash],
  );
  if (!rows[0]) {
    const error = new Error('The reset code is invalid or expired');
    error.status = 400;
    throw error;
  }
  return ok(res, { token: input.code });
}

export async function resetPassword(req, res) {
  const input = validate(resetPasswordSchema, req.body);
  const tokenHash = crypto.createHash('sha256').update(input.token).digest('hex');
  const userId = await pool.getConnection();
  try {
    await userId.beginTransaction();
    const [rows] = await userId.execute(
      "SELECT user_id FROM password_reset_tokens WHERE token_hash = ? AND used_at IS NULL AND datetime(replace(expires_at, 'T', ' ')) > datetime('now')",
      [tokenHash],
    );
    if (!rows[0]) {
      const error = new Error('The password reset link is invalid or expired');
      error.status = 400;
      throw error;
    }
    await userId.execute('UPDATE users SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [await bcrypt.hash(input.newPassword, 12), rows[0].user_id]);
    await userId.execute('UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE token_hash = ?', [tokenHash]);
    await userId.commit();
  } catch (error) {
    await userId.rollback();
    throw error;
  } finally {
    userId.release();
  }
  return ok(res, { message: 'Password has been reset successfully.' });
}

export function me(req, res) { return ok(res, { user: publicUser(req.user) }); }

export async function updateMe(req, res) {
  const input = validate(profileSchema, req.body);
  if (input.newPassword && !input.currentPassword) { const error = new Error('currentPassword is required to change password'); error.status = 422; throw error; }
  if (input.newPassword && !(await bcrypt.compare(input.currentPassword, (await pool.execute('SELECT password FROM users WHERE id = ?', [req.user.id]))[0][0].password))) { const error = new Error('Current password is incorrect'); error.status = 401; throw error; }
  const fields = []; const values = [];
  if (input.name !== undefined) { fields.push('name = ?', 'avatar_initials = ?'); values.push(input.name, input.avatarInitials ?? initials(input.name)); }
  if (input.avatarInitials !== undefined && input.name === undefined) { fields.push('avatar_initials = ?'); values.push(input.avatarInitials); }
  if (input.avatarUrl !== undefined) { fields.push('avatar_url = ?'); values.push(input.avatarUrl); }
  if (input.newPassword) { fields.push('password = ?'); values.push(await bcrypt.hash(input.newPassword, 12)); }
  if (fields.length) { values.push(req.user.id); await pool.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, values); }
  const [rows] = await pool.execute('SELECT id, name, email, role, avatar_initials, avatar_url, created_at, updated_at FROM users WHERE id = ?', [req.user.id]);
  return ok(res, { user: publicUser(rows[0]), token: tokenFor(rows[0]) });
}
