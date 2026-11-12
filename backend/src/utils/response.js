export const ok = (res, data, status = 200) => res.status(status).json({ success: true, data });
export const fail = (res, message, status = 400, details) => res.status(status).json({
  success: false,
  error: { message, ...(details ? { details } : {}) },
});

export function publicUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    avatarInitials: row.avatar_initials,
    avatarUrl: row.avatar_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
