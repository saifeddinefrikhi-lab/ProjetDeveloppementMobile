import crypto from 'node:crypto';
import { pool, withTransaction } from '../config/db.js';
import { ok } from '../utils/response.js';
import { collectionSchema, statusSchema, validate } from '../utils/validation.js';

const select = `SELECT c.id, c.address, c.location_latitude AS latitude, c.location_longitude AS longitude, c.waste_types, c.notes, c.requested_date, c.status, c.created_at, c.updated_at, c.creator_id, creator.name AS creator_name, c.accepted_by AS accepted_by_user_id, acceptor.name AS accepted_by_user_name FROM collection_requests c JOIN users creator ON creator.id = c.creator_id LEFT JOIN users acceptor ON acceptor.id = c.accepted_by`;
function mapRow(row) { return { id: row.id, address: row.address, latitude: row.latitude == null ? null : Number(row.latitude), longitude: row.longitude == null ? null : Number(row.longitude), wasteTypes: typeof row.waste_types === 'string' ? JSON.parse(row.waste_types) : row.waste_types, notes: row.notes, requestedDate: row.requested_date, status: row.status, createdAt: row.created_at, updatedAt: row.updated_at, creatorId: row.creator_id, creatorName: row.creator_name, acceptedByUserId: row.accepted_by_user_id, acceptedByUserName: row.accepted_by_user_name }; }
function coordinates(input) { const coords = input.location?.coordinates || [input.longitude, input.latitude]; return coords?.every((value) => value !== undefined) ? [Number(coords[1]), Number(coords[0])] : [null, null]; }

export async function list(req, res) {
  const { status, mine, lat, lng, distanceKm } = req.query; const where = []; const params = [];
  if (status) { where.push('c.status = ?'); params.push(status); }
  if (mine === 'true') { where.push('c.creator_id = ?'); params.push(req.user.id); }
  if (lat !== undefined || lng !== undefined || distanceKm !== undefined) {
    if (![lat, lng, distanceKm].every((value) => Number.isFinite(Number(value))) || Number(distanceKm) < 0) { const error = new Error('lat, lng and non-negative distanceKm are required for geo filtering'); error.status = 422; throw error; }
    const latitudeDelta = Number(distanceKm) / 111.32;
    const longitudeDelta = latitudeDelta / Math.max(Math.cos(Number(lat) * Math.PI / 180), 0.01);
    where.push('c.location_latitude BETWEEN ? AND ? AND c.location_longitude BETWEEN ? AND ?');
    params.push(Number(lat) - latitudeDelta, Number(lat) + latitudeDelta, Number(lng) - longitudeDelta, Number(lng) + longitudeDelta);
  }
  const [rows] = await pool.execute(`${select} ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY c.created_at DESC`, params);
  return ok(res, { requests: rows.map(mapRow) });
}
export async function getOne(req, res) { const [rows] = await pool.execute(`${select} WHERE c.id = ?`, [req.params.id]); if (!rows[0]) { const e = new Error('Collection request not found'); e.status = 404; throw e; } return ok(res, { request: mapRow(rows[0]) }); }
export async function create(req, res) { const input = validate(collectionSchema, req.body); const id = crypto.randomUUID(); const [latitude, longitude] = coordinates(input); await pool.execute('INSERT INTO collection_requests (id, creator_id, address, location_latitude, location_longitude, waste_types, notes, requested_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [id, req.user.id, input.address, latitude, longitude, JSON.stringify(input.wasteTypes), input.notes || null, new Date(input.requestedDate)]); const [rows] = await pool.execute(`${select} WHERE c.id = ?`, [id]); return ok(res, { request: mapRow(rows[0]) }, 201); }
export async function accept(req, res) { if (!['collector', 'admin'].includes(req.user.role)) { const e = new Error('Only collectors can accept requests'); e.status = 403; throw e; } const [result] = await pool.execute("UPDATE collection_requests SET status = 'accepted', accepted_by = ? WHERE id = ? AND status = 'pending'", [req.user.id, req.params.id]); if (!result.affectedRows) { const e = new Error('Request is missing or no longer pending'); e.status = 409; throw e; } return getOne(req, res); }
export async function updateStatus(req, res) { const input = validate(statusSchema, req.body); const [rows] = await pool.execute('SELECT creator_id, accepted_by, status FROM collection_requests WHERE id = ?', [req.params.id]); const current = rows[0]; if (!current) { const e = new Error('Collection request not found'); e.status = 404; throw e; } const allowed = req.user.role === 'admin' || (input.status === 'cancelled' && current.creator_id === req.user.id) || (input.status === 'completed' && (current.accepted_by === req.user.id || req.user.role === 'collector')); if (!allowed) { const e = new Error('You cannot update this request'); e.status = 403; throw e; } await pool.execute('UPDATE collection_requests SET status = ? WHERE id = ?', [input.status, req.params.id]); return getOne(req, res); }
export async function remove(req, res) { const [result] = await pool.execute("UPDATE collection_requests SET status = 'cancelled' WHERE id = ? AND creator_id = ? AND status IN ('pending','accepted')", [req.params.id, req.user.id]); if (!result.affectedRows) { const e = new Error('Request not found or cannot be cancelled'); e.status = 404; throw e; } return ok(res, { message: 'Collection request cancelled' }); }
