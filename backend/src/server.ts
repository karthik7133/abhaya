import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { initFirebase, getFirebaseAdmin } from './config/firebase';
import { User, Message, EmergencyEvent, LiveLocation, MoodTrend, IncidentReport, Journey, DeviceContact, TrustedContact } from './models';
import { telemetryMonitor } from './middleware/telemetryMonitor';
import healthRoutes from './routes/health';

import userRoutes from './routes/users';
import connectionRoutes from './routes/connections';
import chatRoutes from './routes/chat';
import emergencyRoutes from './routes/emergency';
import locationRoutes from './routes/location';
import moodRoutes from './routes/mood';
import incidentRoutes from './routes/incidents';
import journeyRoutes from './routes/journeys';
import contactsRoutes from './routes/contacts';
import rateLimit from 'express-rate-limit';

dotenv.config();

// ─── App Setup ────────────────────────────────────────────────────────────────
const app = express();
const PORT = Number(process.env.PORT) || 5000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors({
  origin: '*', // tighten this in production
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(helmet());
app.use(morgan('dev'));

// Rate limiters
const generalLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 200 });
const sosLimiter     = rateLimit({ windowMs: 60 * 1000,       max: 5, message: { error: 'Too many SOS requests' } });
const chatLimiter    = rateLimit({ windowMs: 60 * 1000,       max: 30, message: { error: 'Chat rate limit exceeded' } });

app.use(generalLimiter);
app.use(telemetryMonitor);

// ─── Initialize Services ──────────────────────────────────────────────────────
initFirebase();

const MONGO_URI = process.env.MONGODB_URI;
if (!MONGO_URI) {
  console.error('❌ MONGODB_URI is not set in environment variables.');
  process.exit(1);
}

const connectWithRetry = async () => {
  const maxRetries = 5;
  let retries = 0;
  
  while (retries < maxRetries) {
    try {
      await mongoose.connect(MONGO_URI);
      console.log('✅ Connected to MongoDB Atlas');
      return;
    } catch (err) {
      retries++;
      console.error(`❌ MongoDB connection error (Attempt ${retries}/${maxRetries}):`, err);
      if (retries === maxRetries) {
        console.error('❌ Max retries reached. Could not connect to MongoDB.');
        process.exit(1);
      }
      // Wait for 5 seconds before retrying (exponential backoff could be applied here)
      await new Promise(res => setTimeout(res, 5000));
    }
  }
};
connectWithRetry();

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/users', userRoutes);
app.use('/api/connections', connectionRoutes);
app.use('/api/chat', chatLimiter, chatRoutes);
app.use('/api/emergency', emergencyRoutes);
app.use('/api/emergency/sos', sosLimiter); // extra rate limit on SOS endpoint
app.use('/api/location', locationRoutes);
app.use('/api/mood', moodRoutes);
app.use('/api/incidents', incidentRoutes);
app.use('/api/journeys', journeyRoutes);
app.use('/api/contacts', contactsRoutes);
app.use('/api/health', healthRoutes); // Advanced API Health Monitor

// ─── Error Handling ───────────────────────────────────────────────────────────
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('[Global Error]', err);
  res.status(500).json({ error: 'Internal Server Error' });
});

// ─── Start Server ─────────────────────────────────────────────────────────────
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
  console.log(`🌐 Access via network: http://192.168.1.27:${PORT}`);

  // Pre-warm Ollama model in background so first user chat isn't slow
  const OLLAMA_BASE  = process.env.OLLAMA_BASE_URL ?? 'http://localhost:11434';
  const OLLAMA_MODEL = process.env.OLLAMA_MODEL    ?? 'potti_ai:latest';
  const axios = require('axios');

  console.log(`[Ollama] Pre-warming model: ${OLLAMA_MODEL}...`);
  axios.post(`${OLLAMA_BASE}/api/chat`, {
    model:    OLLAMA_MODEL,
    messages: [{ role: 'user', content: 'hi' }],
    stream:   false,
    options:  { num_predict: 1 }, // generate only 1 token — just warm up
  }, { timeout: 180_000 })
    .then(() => console.log('[Ollama] ✅ Model warmed up and ready'))
    .catch((e: Error) => console.warn(`[Ollama] ⚠️ Warmup failed (will retry on first chat): ${e.message}`));
});

// ─── Background Job: Cleanup Deleted Firebase Users ───────────────────────────
async function cleanupDeletedUsers() {
  try {
    const firebaseUsers = new Set<string>();
    let pageToken: string | undefined = undefined;
    do {
      const result = await getFirebaseAdmin().auth().listUsers(1000, pageToken);
      result.users.forEach(u => firebaseUsers.add(u.uid));
      pageToken = result.pageToken;
    } while (pageToken);

    const mongoUsers = await User.find({}, { uid: 1 });
    const deletedUids = mongoUsers.map(u => u.uid).filter(uid => !firebaseUsers.has(uid));

    if (deletedUids.length > 0) {
      console.log(`[Cleanup] Found ${deletedUids.length} users deleted from Firebase. Removing from MongoDB...`);
      for (const uid of deletedUids) {
        await Promise.all([
          User.deleteOne({ uid }),
          Message.deleteMany({ userId: uid }),
          EmergencyEvent.deleteMany({ userId: uid }),
          LiveLocation.deleteOne({ userId: uid }),
          MoodTrend.deleteMany({ userId: uid }),
          IncidentReport.deleteMany({ userId: uid }),
          Journey.deleteMany({ userId: uid }),
          DeviceContact.deleteMany({ userId: uid }),
          TrustedContact.deleteMany({ userId: uid }),
        ]);
        console.log(`[Cleanup] Deleted data for uid: ${uid}`);
      }
    }
  } catch (err) {
    console.error('[Cleanup] Error during user cleanup job:', err);
  }
}
setInterval(cleanupDeletedUsers, 1000 * 60 * 60); // every 1 hour
setTimeout(cleanupDeletedUsers, 10000); // run shortly after startup

// ─── Graceful Shutdown (Session & Connection Recovery) ────────────────────────
const gracefulShutdown = async (signal: string) => {
  console.log(`\n🛑 Received ${signal}. Starting graceful shutdown...`);
  
  try {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
      console.log('✅ MongoDB connection closed gracefully.');
    }
    
    server.close(() => {
      console.log('✅ HTTP server closed.');
      process.exit(0);
    });
    
    // Force shutdown if it takes too long
    setTimeout(() => {
      console.error('❌ Forced shutdown after timeout.');
      process.exit(1);
    }, 10000);
  } catch (err) {
    console.error('❌ Error during shutdown:', err);
    process.exit(1);
  }
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
