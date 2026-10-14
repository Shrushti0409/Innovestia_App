import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import authRoutes from './routes/authRoutes.js';
import apiRoutes from './routes/apiRoutes.js';
import adminRoutes from './routes/adminRoutes.js';
import { errorHandler, notFound } from './middleware/errors.js';

const app = express();
const configuredOrigins = process.env.CORS_ORIGIN
  ?.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.disable('x-powered-by');
app.use(cors({
  origin(origin, callback) {
    // Native clients do not send an Origin header.
    if (!origin || !configuredOrigins?.length || configuredOrigins.includes(origin)) {
      return callback(null, true);
    }

    // Flutter Web's development server chooses a port dynamically. Allow only
    // loopback origins in development; production still uses CORS_ORIGIN.
    if (process.env.NODE_ENV !== 'production') {
      try {
        const { hostname, protocol } = new URL(origin);
        if (
          ['http:', 'https:'].includes(protocol) &&
          ['localhost', '127.0.0.1', '[::1]'].includes(hostname)
        ) {
          return callback(null, true);
        }
      } catch {
        // Reject malformed origins below.
      }
    }

    return callback(new Error('Origin is not allowed by CORS.'));
  },
}));
app.use(express.json({ limit: '1mb' }));
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) =>
    req.path === '/api/auth/login' || req.path === '/api/auth/register',
}));
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/api/health', (req, res) => res.status(200).json({ status: 'ok' }));
app.use('/api/auth', authRoutes);
app.use('/api', apiRoutes);
app.use('/api/admin', adminRoutes);
app.use(notFound);
app.use(errorHandler);

export default app;
