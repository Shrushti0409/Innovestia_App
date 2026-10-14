import jwt from 'jsonwebtoken';
import User from '../models/User.js';
export async function authenticate(req, res, next) { try { const token = req.headers.authorization?.replace('Bearer ', ''); if (!token) return res.status(401).json({message: 'Authentication is required.'}); const payload = jwt.verify(token, process.env.JWT_SECRET); req.user = await User.findById(payload.sub).select('-passwordHash'); if (!req.user) return res.status(401).json({message: 'Session expired. Please log in again.'}); next(); } catch { res.status(401).json({message: 'Session expired. Please log in again.'}); } }
export const authorize = (...roles) => (req, res, next) => roles.includes(req.user.role) ? next() : res.status(403).json({message: 'Permission denied.'});
