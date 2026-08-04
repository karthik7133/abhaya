import { Request, Response, NextFunction } from 'express';

/**
 * Service Availability & Network Quality Monitor
 * Middleware that tracks request execution time and logs telemetry data.
 */
export const telemetryMonitor = (req: Request, res: Response, next: NextFunction) => {
  const start = process.hrtime();

  res.on('finish', () => {
    const diff = process.hrtime(start);
    const durationMs = (diff[0] * 1e3 + diff[1] * 1e-6).toFixed(2);
    
    const statusCode = res.statusCode;
    const isError = statusCode >= 400;
    
    // In a production app, this could be pushed to DataDog, Prometheus, or ELK
    const logPrefix = isError ? '❌ [API Fault]' : '✅ [API Telemetry]';
    
    console.log(`${logPrefix} ${req.method} ${req.originalUrl} | Status: ${statusCode} | Duration: ${durationMs}ms`);
  });

  next();
};
