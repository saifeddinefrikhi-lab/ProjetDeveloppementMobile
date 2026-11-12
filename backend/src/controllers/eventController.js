import crypto from 'node:crypto';
import { pool, withTransaction } from '../config/db.js';
import { ok } from '../utils/response.js';
import { attendanceSchema, eventSchema, eventStatusSchema, validate } from '../utils/validation.js';

const select = `
  SELECT e.id, e.title, e.description, e.event_type, e.location, e.latitude, e.longitude, e.starts_at,
    e.ends_at, e.capacity, e.status, e.organizer_id, u.name AS organizer_name,
    e.created_at, e.updated_at,
    COUNT(r.user_id) AS participant_count,
    MAX(CASE WHEN r.user_id = ? THEN 1 ELSE 0 END) AS registered
  FROM ecological_events e
  JOIN users u ON u.id = e.organizer_id
  LEFT JOIN event_registrations r ON r.event_id = e.id`;

function mapRow(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    eventType: row.event_type,
    location: row.location,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    capacity: Number(row.capacity),
    status: row.status,
    organizerId: Number(row.organizer_id),
    organizerName: row.organizer_name,
    participantCount: Number(row.participant_count),
    isRegistered: Boolean(row.registered),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function findEvent(id, userId) {
  
  const [rows] = await pool.execute(
    `${select} WHERE e.id = ? AND e.latitude IS NOT NULL AND e.longitude IS NOT NULL GROUP BY e.id`,
    [userId, id],
  );
  return rows[0];
}

async function assertOrganizerOrAdmin(eventId, user) {
  if (user.role === 'admin') return;
  const [rows] = await pool.execute(
    'SELECT id FROM ecological_events WHERE id = ? AND organizer_id = ?',
    [eventId, user.id],
  );
  if (!rows[0]) {
    const error = new Error('Only the event organizer can manage participants');
    error.status = 403;
    throw error;
  }
}

export async function list(req, res) {
  const params = [req.user.id];
  const filters = ['e.latitude IS NOT NULL', 'e.longitude IS NOT NULL'];
  if (req.query.status) {
    filters.push('e.status = ?');
    params.push(req.query.status);
  }
  if (req.query.mine === 'true') {
    filters.push('r.user_id = ?');
    params.push(req.user.id);
  }
  const [rows] = await pool.execute(
    `${select} ${filters.length ? `WHERE ${filters.join(' AND ')}` : ''} GROUP BY e.id ORDER BY e.starts_at ASC`,
    params,
  );
  return ok(res, { events: rows.map(mapRow) });
}

export async function getOne(req, res) {
  const row = await findEvent(req.params.id, req.user.id);
  if (!row) {
    const error = new Error('Event not found');
    error.status = 404;
    throw error;
  }
  return ok(res, { event: mapRow(row) });
}

export async function create(req, res) {
  const input = validate(eventSchema, req.body);
  const id = crypto.randomUUID();
  await pool.execute(
    `INSERT INTO ecological_events
      (id, organizer_id, title, description, event_type, location, latitude, longitude, starts_at, ends_at, capacity)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, req.user.id, input.title, input.description, input.eventType, input.location,
      input.latitude, input.longitude, new Date(input.startsAt), new Date(input.endsAt), input.capacity],
  );
  return getOne({ ...req, params: { id } }, res);
}

export async function update(req, res) {
  const input = validate(eventSchema, req.body);
  const [result] = await pool.execute(
    `UPDATE ecological_events
     SET title = ?, description = ?, event_type = ?, location = ?, latitude = ?,
       longitude = ?, starts_at = ?, ends_at = ?, capacity = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ? AND organizer_id = ?`,
    [input.title, input.description, input.eventType, input.location, input.latitude,
      input.longitude, new Date(input.startsAt), new Date(input.endsAt), input.capacity,
      req.params.id, req.user.id],
  );
  if (!result.affectedRows) {
    const error = new Error('Event not found or you are not the organizer');
    error.status = 404;
    throw error;
  }
  return getOne(req, res);
}

export async function remove(req, res) {
  const [result] = await pool.execute(
    'DELETE FROM ecological_events WHERE id = ? AND organizer_id = ?',
    [req.params.id, req.user.id],
  );
  if (!result.affectedRows) {
    const error = new Error('Event not found or you are not the organizer');
    error.status = 404;
    throw error;
  }
  return ok(res, { message: 'Event deleted successfully' });
}

export async function register(req, res) {
  await withTransaction(async (connection) => {
    const [events] = await connection.execute(
      'SELECT id, capacity, status FROM ecological_events WHERE id = ?',
      [req.params.id],
    );
    if (!events[0]) {
      const error = new Error('Event not found');
      error.status = 404;
      throw error;
    }
    if (events[0].status !== 'planned') {
      const error = new Error('This event is no longer open for registration');
      error.status = 409;
      throw error;
    }
    const [existing] = await connection.execute(
      'SELECT event_id FROM event_registrations WHERE event_id = ? AND user_id = ?',
      [req.params.id, req.user.id],
    );
    if (existing[0]) {
      const error = new Error('You are already registered for this event');
      error.status = 409;
      throw error;
    }
    const [count] = await connection.execute(
      'SELECT COUNT(*) AS total FROM event_registrations WHERE event_id = ?',
      [req.params.id],
    );
    if (Number(count[0].total) >= Number(events[0].capacity)) {
      const error = new Error('This event is full');
      error.status = 409;
      throw error;
    }
    await connection.execute(
      'INSERT INTO event_registrations (event_id, user_id) VALUES (?, ?)',
      [req.params.id, req.user.id],
    );
    return true;
  });
  return getOne(req, res);
}

export async function unregister(req, res) {
  const [result] = await pool.execute(
    'DELETE FROM event_registrations WHERE event_id = ? AND user_id = ?',
    [req.params.id, req.user.id],
  );
  if (!result.affectedRows) {
    const error = new Error('Registration not found');
    error.status = 404;
    throw error;
  }
  return getOne(req, res);
}

export async function updateStatus(req, res) {
  const input = validate(eventStatusSchema, req.body);
  await assertOrganizerOrAdmin(req.params.id, req.user);
  const [result] = await pool.execute(
    'UPDATE ecological_events SET status = ? WHERE id = ?',
    [input.status, req.params.id],
  );
  if (!result.affectedRows) {
    const error = new Error('Event not found');
    error.status = 404;
    throw error;
  }
  return getOne(req, res);
}

export async function participants(req, res) {
  await assertOrganizerOrAdmin(req.params.id, req.user);
  const [rows] = await pool.execute(
    `SELECT r.user_id, u.name, u.email, r.registered_at, r.attended
     FROM event_registrations r JOIN users u ON u.id = r.user_id
     WHERE r.event_id = ? ORDER BY u.name`,
    [req.params.id],
  );
  return ok(res, {
    participants: rows.map((row) => ({
      userId: Number(row.user_id),
      name: row.name,
      email: row.email,
      registeredAt: row.registered_at,
      attended: row.attended == null ? null : Boolean(row.attended),
    })),
  });
}

export async function updateAttendance(req, res) {
  const input = validate(attendanceSchema, req.body);
  await assertOrganizerOrAdmin(req.params.id, req.user);
  const [registrations] = await pool.execute(
    'SELECT event_id FROM event_registrations WHERE event_id = ? AND user_id = ?',
    [req.params.id, req.params.userId],
  );
  if (!registrations[0]) {
    const error = new Error('Participant registration not found');
    error.status = 404;
    throw error;
  }
  const [result] = await pool.execute(
    'UPDATE event_registrations SET attended = ? WHERE event_id = ? AND user_id = ?',
    [input.attended ? 1 : 0, req.params.id, req.params.userId],
  );
  return participants(req, res);
}
