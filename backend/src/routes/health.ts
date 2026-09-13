import { Router } from 'express';
import mongoose from 'mongoose';
import os from 'os';

const router = Router();

/**
 * General API Health check endpoint (/api/health)
 */
router.get('/', (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  res.status(isDbConnected ? 200 : 503).json({
    status: isDbConnected ? 'healthy' : 'degraded',
    database: isDbConnected ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

/**
 * Advanced API Health Monitor Route
 * Returns deep system diagnostics, memory usage, and database state.
 */
router.get('/system', (req, res) => {
  const dbState = mongoose.connection.readyState;
  
  // Mongoose ready states: 0: disconnected, 1: connected, 2: connecting, 3: disconnecting, 99: uninitialized
  const dbStatusMap: { [key: number]: string } = {
    0: 'Disconnected',
    1: 'Connected',
    2: 'Connecting',
    3: 'Disconnecting',
    99: 'Uninitialized'
  };

  const isDbConnected = dbState === 1;
  const isHealthy = isDbConnected; // Add more checks here if needed in future

  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;

  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    metrics: {
      uptimeSeconds: process.uptime(),
      memoryUsage: {
        total: `${(totalMem / 1024 / 1024).toFixed(2)} MB`,
        used: `${(usedMem / 1024 / 1024).toFixed(2)} MB`,
        free: `${(freeMem / 1024 / 1024).toFixed(2)} MB`,
      },
      cpuLoadAvg: os.loadavg(),
    },
    database: {
      status: dbStatusMap[dbState] || 'Unknown',
      isConnected: isDbConnected
    },
    version: '1.0.1' // Incremented version for new reliability features
  });
});

export default router;
