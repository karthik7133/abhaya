import { Request, Response, NextFunction } from 'express';
import { verifyIdToken } from '../config/firebase';

// Extend Express Request to include the decoded Firebase user
declare global {
  namespace Express {
    interface Request {
      firebaseUser?: {
        uid: string;
        email?: string;
        name?: string;
        picture?: string;
      };
    }
  }
}

/**
 * Middleware: validates the Firebase ID token in the Authorization header.
 * Sets req.firebaseUser on success, returns 401 on failure.
 */
export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const idToken = authHeader.split('Bearer ')[1];

  try {
    const decoded = await verifyIdToken(idToken);
    req.firebaseUser = {
      uid:     decoded.uid,
      email:   decoded.email,
      name:    decoded.name,
      picture: decoded.picture,
    };
    next();
  } catch (err) {
    console.error('[Auth] Token verification failed:', err);
    res.status(401).json({ error: 'Unauthorized — invalid or expired token' });
  }
}
