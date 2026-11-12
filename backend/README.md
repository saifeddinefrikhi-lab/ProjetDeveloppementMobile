# Waste Classification REST API

Production-oriented Express/SQLite backend for the Flutter waste classification and collection app.

## Requirements

- Node.js 20+
- Node.js 22.5+ (uses the built-in `node:sqlite` driver)

## Setup

1. Copy `.env.example` to `.env` and set a strong `JWT_SECRET`.
2. Install dependencies with `npm install`.
3. Create tables with `npm run db:migrate`.
4. Start the model service from `ml-service` using its README instructions.
5. Start development mode with `npm run dev`, or production mode with `npm start`.

The API listens on `PORT` (default `3000`). A health check is available at `/health`.

Password reset emails use the Gmail API by default. Configure
`GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`, and
`GMAIL_FROM` in `.env`. The OAuth token must include the Gmail
`https://www.googleapis.com/auth/gmail.send` scope. Set `EMAIL_PROVIDER=smtp`
to use the SMTP configuration instead. Reset tokens expire after one hour and
are single-use.

## Endpoints

All successful responses use `{ "success": true, "data": ... }`; errors use `{ "success": false, "error": ... }`. Authenticated requests send `Authorization: Bearer <token>`.

- `POST /api/v1/auth/register` `{ name, email, password }` (new accounts always start as `user`)
- `POST /api/v1/auth/login` `{ email, password }`
- `POST /api/v1/auth/forgot-password` `{ email }` (emails a six-digit code)
- `POST /api/v1/auth/verify-reset-code` `{ email, code }`
- `POST /api/v1/auth/reset-password` `{ token, newPassword }`
- `GET /api/v1/auth/me`
- `PUT /api/v1/auth/me` `{ name?, avatarInitials?, avatarUrl?, currentPassword?, newPassword? }`
- `GET /api/v1/collections?status=pending&mine=true&lat=...&lng=...&distanceKm=...`
- `POST /api/v1/collections` `{ address, latitude, longitude, wasteTypes, notes?, requestedDate }`
- `GET /api/v1/collections/:id`
- `PATCH /api/v1/collections/:id/accept` (collector/admin)
- `PATCH /api/v1/collections/:id/status` `{ status: "completed" | "cancelled" }`
- `DELETE /api/v1/collections/:id`
- `GET /api/v1/scans?page=1&limit=20&sort=scanned_at&order=desc`
- `POST /api/v1/scans` multipart field `image` plus `categoryId`, `modelLabel`, `confidence`, `scannedAt?`
- `GET /api/v1/scans/stats`
- `POST /api/v1/classify` multipart field `image`; proxies to `ML_SERVICE_URL`

The bundled model is served by `backend/ml-service` on
`http://127.0.0.1:8000/predict`. The Flutter camera and file-upload flows both
call `/api/v1/classify`, so they use the same local model.

SQLite stores collection coordinates as latitude/longitude columns and `wasteTypes` as JSON text, returned as an array. Scan uploads are limited to JPEG, PNG, and WebP and the configured maximum size. The database file defaults to `data/waste_classification.sqlite` and can be changed with `SQLITE_DB_PATH`.

## Production notes

- Use a secret manager for `.env` values and set `NODE_ENV=production`.
- Put the API behind TLS/reverse proxy and set `CORS_ORIGIN` to the exact Flutter web origin(s).
- Use object storage instead of the local `uploads/` directory for multi-instance deployments.
- Add rate limiting and centralized log shipping at the edge/application platform.
- Never expose the database directly to clients.
