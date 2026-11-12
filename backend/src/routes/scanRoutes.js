import { Router } from 'express';
import * as controller from '../controllers/scanController.js';
import { requireAuth } from '../middleware/auth.js';
import { upload } from '../middleware/upload.js';
const router = Router();
router.use(requireAuth);

router.get('/', controller.list);
router.get('/stats', controller.stats);
router.post('/', upload.single('image'), controller.create);
export default router;
