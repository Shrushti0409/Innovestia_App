import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import Profile from '../models/Profile.js';

const publicUser = user => ({id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role});
const tokenFor = user => jwt.sign({sub: user.id, role: user.role}, process.env.JWT_SECRET, {expiresIn: process.env.JWT_EXPIRES_IN || '7d'});
const normalizeEmail = value => typeof value === 'string' ? value.trim().toLowerCase() : '';

export async function register(req, res) {
  const {name, email, phone, password, role} = req.body || {};
  const normalizedEmail = normalizeEmail(email);
  if (typeof name !== 'string' || !name.trim() || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail) || typeof password !== 'string' || !['STARTUP', 'INVESTOR'].includes(role)) return res.status(422).json({message: 'Please provide a valid name, email, password, and account type.'});
  if (password.length < 8) return res.status(422).json({message: 'Password must be at least 8 characters.'});
  if (await User.exists({email: normalizedEmail})) return res.status(409).json({message: 'Email already registered. Try logging in.'});
  const user = await User.create({name: name.trim(), email: normalizedEmail, phone: typeof phone === 'string' ? phone.trim() : undefined, role, passwordHash: await bcrypt.hash(password, 12)});
  try {
    await Profile.create({user: user.id, type: role, name: user.name});
  } catch (error) {
    // MongoDB standalone servers do not support multi-document transactions.
    // Roll back only this request's newly-created user if profile creation
    // fails, leaving unrelated accounts and collections untouched.
    await User.deleteOne({_id: user.id});
    throw error;
  }
  res.status(201).json({data: {token: tokenFor(user), user: publicUser(user)}});
}

export async function login(req, res) {
  const user = await User.findOne({email: normalizeEmail(req.body?.email)}).select('+passwordHash');
  if (!user || !await bcrypt.compare(req.body?.password || '', user.passwordHash)) return res.status(401).json({message: 'Invalid email or password.'});
  res.json({data: {token: tokenFor(user), user: publicUser(user)}});
}

export async function me(req, res) { res.json({data: {user: publicUser(req.user)}}); }
