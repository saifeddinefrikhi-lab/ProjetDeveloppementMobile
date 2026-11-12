import { Router } from 'express';
import { forgotPassword, login, me, register, resetPassword, updateMe, verifyResetCode } from '../controllers/authController.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
router.post('/register', register);
router.post('/login', login);
router.post('/forgot-password', forgotPassword);
router.post('/verify-reset-code', verifyResetCode);
router.post('/reset-password', resetPassword);
router.get('/me', requireAuth, me);
router.put('/me', requireAuth, updateMe);

export default router;
