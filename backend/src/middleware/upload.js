import multer from 'multer';
import path from 'node:path';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { env } from '../config/env.js';

const directory = path.resolve(env.uploadDir);

fs.mkdirSync(directory, { recursive: true });
const allowed = new Set(['image/jpeg', 'image/png', 'image/webp']);
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, directory),
  filename: (_req, file, cb) => cb(null, `${crypto.randomUUID()}${path.extname(file.originalname).toLowerCase()}`),
});
export const upload = multer({
  storage,
  limits: { fileSize: env.maxFileSizeMb * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (allowed.has(file.mimetype)) return cb(null, true);
    const error = new Error('Only JPEG, PNG, and WebP images are allowed');
    error.status = 415;
    return cb(error);
  },
});
