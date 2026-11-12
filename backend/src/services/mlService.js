import fs from 'node:fs/promises';
import { env } from '../config/env.js';

export async function classifyImage(file) {
  const body = new FormData();
  body.append('file', new Blob([await fs.readFile(file.path)], { type: file.mimetype }), file.originalname);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.mlServiceTimeoutMs);
  try {
    const response = await fetch(env.mlServiceUrl, { method: 'POST', body, signal: controller.signal });
    if (!response.ok) { const error = new Error('Classifier service unavailable'); error.status = 502; throw error; }
    const result = await response.json();
    const confidence = Math.max(0, Math.min(1, Number(result.confidence)));
    if (!result.predicted_class || !Number.isFinite(confidence)) { const error = new Error('Classifier returned an invalid response'); error.status = 502; throw error; }
    return { predicted_class: result.predicted_class, category_id: result.category_id || categoryFor(result.predicted_class), confidence, all_probabilities: result.all_probabilities || {} };
  } catch (error) {
    if (error.name === 'AbortError') { error.status = 504; error.message = 'Classifier request timed out'; }
    if (!error.status) { error.status = 502; error.message = 'Classifier service unavailable'; }
    throw error;
  } finally { clearTimeout(timeout); }
}
function categoryFor(label) {
  return ['food organics', 'vegetation', 'organic'].includes(String(label).toLowerCase()) ? 'organic' : ['cardboard', 'glass', 'metal', 'paper', 'plastic'].includes(String(label).toLowerCase()) ? 'recyclable' : 'other';
}
