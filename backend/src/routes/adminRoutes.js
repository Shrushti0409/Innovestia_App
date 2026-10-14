import {Router} from 'express';
import User from '../models/User.js'; import Profile from '../models/Profile.js'; import InvestmentRequest from '../models/InvestmentRequest.js';
import {authenticate, authorize} from '../middleware/auth.js';
const router = Router(); router.use(authenticate, authorize('ADMIN'));
router.get('/stats', async (req, res) => { const [users, startups, investors, pending] = await Promise.all([User.countDocuments(), Profile.countDocuments({type: 'STARTUP'}), Profile.countDocuments({type: 'INVESTOR'}), InvestmentRequest.countDocuments({status: 'PENDING'})]); res.json({data: {users, startups, investors, pending}}); });
router.get('/users', async (req, res) => res.json({data: {items: await User.find().select('-passwordHash').sort('-createdAt').limit(100)}}));
router.put('/users/:id/verify', async (req, res) => { const user = await User.findByIdAndUpdate(req.params.id, {isVerified: true}, {new: true}).select('-passwordHash'); if (!user) return res.status(404).json({message: 'User not found.'}); res.json({data: {user}}); }); export default router;
