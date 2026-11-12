import { Router } from 'express';
import { classify } from '../controllers/classifyController.js';
import { upload } from '../middleware/upload.js';
import { relayClassificationLog } from '../services/classificationLogService.js';

const router = Router();

router.use((req, res, next) => {
  const startedAt = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    void relayClassificationLog({
      method: req.method,
      path: '/api/v1/classify',
      status: res.statusCode,
      duration_ms: Number(durationMs.toFixed(3)),
      response_bytes: Number(res.getHeader('content-length') || 0),
    });
  });
  next();
});

router.post('/', upload.single('image'), classify);
export default router;
