import { Router } from 'express';
import * as controller from '../controllers/collectionController.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();

router.use(requireAuth);
router.get('/', controller.list);
router.post('/', controller.create);
router.get('/:id', controller.getOne);
router.patch('/:id/accept', controller.accept);
router.patch('/:id/status', controller.updateStatus);
router.delete('/:id', controller.remove);
export default router;
