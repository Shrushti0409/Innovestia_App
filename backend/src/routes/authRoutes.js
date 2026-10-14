import {Router} from 'express';
import rateLimit from 'express-rate-limit';
import {login, me, register} from '../controllers/authController.js';
import {authenticate} from '../middleware/auth.js';
import {asyncHandler} from '../middleware/errors.js';

const router = Router();
export const authAttemptLimiter = rateLimit({
  windowMs: 15 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, res) => {
    res.setHeader('Retry-After', '15');
    res.status(429).json({
      message: 'Too many attempts. Please try again in 15 seconds.',
    });
  },
});

router.post('/register', authAttemptLimiter, asyncHandler(register));
router.post('/login', authAttemptLimiter, asyncHandler(login));
router.get('/me', authenticate, asyncHandler(me));
router.post('/logout', authenticate, (req, res) => res.status(204).end());

export default router;
