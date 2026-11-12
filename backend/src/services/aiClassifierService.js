import fs from 'node:fs/promises';
import { env } from '../config/env.js';
import { classifyImage as classifyWithMlService } from './mlService.js';

const ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
const LABELS = [
  'Cardboard',
  'Food Organics',
  'Glass',
  'Metal',
  'Miscellaneous Trash',
  'Paper',
  'Plastic',
  'Textile Trash',
  'Vegetation',
];

const PROMPT = `Classify the main waste item in this image into exactly one label:
${LABELS.join(', ')}.
Return only JSON with this shape:
{"predicted_class":"<label>","confidence":<number between 0 and 1>}`;

export async function classifyImage(file) {
  if (env.aiClassifierProvider === 'ml') {
    return classifyWithMlService(file);
  }
  if (env.aiClassifierProvider !== 'groq') {
    const error = new Error('Unsupported classifier provider');
    error.status = 500;
    throw error;
  }
  if (!env.groq.apiKey) {
    const error = new Error('AI classifier API key is not configured');
    error.status = 503;
    throw error;
  }

  const image = (await fs.readFile(file.path)).toString('base64');
  const response = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.groq.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.groq.model,
      temperature: 0,
      max_completion_tokens: 128,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: PROMPT },
            {
              type: 'image_url',
              image_url: {
                url: `data:${file.mimetype};base64,${image}`,
              },
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const responseBody = await response.text();
    console.error(
      `[classifier] upstream request failed: status=${response.status} body=${responseBody.slice(0, 500)}`,
    );
    const error = new Error('AI classifier request failed');
    error.status = response.status === 429 ? 503 : 502;
    throw error;
  }

  const payload = await response.json();
  const content = payload.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content.trim()) {
    const error = new Error('AI classifier returned an invalid response');
    error.status = 502;
    throw error;
  }

  let result;
  try {
    result = JSON.parse(content);
  } catch (error) {
    const parseError = new Error('AI classifier returned invalid JSON');
    parseError.status = 502;
    throw parseError;
  }

  const label = LABELS.find(
    (candidate) =>
      candidate.toLowerCase() === String(result.predicted_class || '').trim().toLowerCase(),
  );
  const confidence = Number(result.confidence);
  if (!label || !Number.isFinite(confidence)) {
    const error = new Error('AI classifier returned an invalid classification');
    error.status = 502;
    throw error;
  }

  return {
    predicted_class: label,
    category_id: categoryFor(label),
    confidence: Math.max(0, Math.min(1, confidence)),
    all_probabilities: { [label]: Math.max(0, Math.min(1, confidence)) },
  };
}

function categoryFor(label) {
  if (['Food Organics', 'Vegetation'].includes(label)) return 'organic';
  if (['Cardboard', 'Glass', 'Metal', 'Paper', 'Plastic'].includes(label)) {
    return 'recyclable';
  }
  return 'other';
}
