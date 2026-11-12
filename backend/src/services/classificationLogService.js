import { env } from '../config/env.js';

export async function relayClassificationLog(entry) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  try {
    await fetch(env.mlServiceLogUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(entry),
      signal: controller.signal,
    });
  } catch (error) {
    console.warn(`[classifier] ML-service log relay unavailable: ${error.message}`);
  } finally {
    clearTimeout(timeout);
  }
}
