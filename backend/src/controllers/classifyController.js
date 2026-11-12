import fs from 'node:fs/promises';
import { classifyImage } from '../services/aiClassifierService.js';
import { ok } from '../utils/response.js';


export async function classify(req, res) { if (!req.file) { const e = new Error('An image file is required'); e.status = 422; throw e; } try { return ok(res, await classifyImage(req.file)); } finally { await fs.unlink(req.file.path).catch(() => {}); } }
