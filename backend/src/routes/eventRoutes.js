import { Router } from 'express';
import * as controller from '../controllers/eventController.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);
router.get('/', controller.list);
router.post('/', controller.create);
router.get('/:id', controller.getOne);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);
router.post('/:id/register', controller.register);
router.delete('/:id/register', controller.unregister);
router.patch('/:id/status', controller.updateStatus);
router.get('/:id/participants', controller.participants);
router.patch('/:id/participants/:userId/attendance', controller.updateAttendance);
export default router;
