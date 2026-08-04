import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth';
import { Journey } from '../models';

const router = Router();

// POST /api/journeys
// Save a completed journey
router.post('/', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.firebaseUser!.uid;
    const {
      destination,
      startedAt,
      arrivedAt,
      durationSeconds,
      distanceMeters,
      checkInsCount,
      safetyScore,
      nightModeActive,
      routeType,
      waypoints,
    } = req.body;

    const journey = new Journey({
      userId,
      destination,
      startedAt: new Date(startedAt),
      arrivedAt: new Date(arrivedAt),
      durationSeconds,
      distanceMeters,
      checkInsCount,
      safetyScore,
      nightModeActive,
      routeType,
      waypoints: waypoints || [],
    });

    await journey.save();

    res.status(201).json({
      success: true,
      message: 'Journey saved successfully',
      journey,
    });
  } catch (error) {
    console.error('[Journeys Route] Error saving journey:', error);
    res.status(500).json({ success: false, message: 'Failed to save journey' });
  }
});

// GET /api/journeys
// Get past journeys for the authenticated user
router.get('/', authMiddleware, async (req: Request, res: Response) => {
  try {
    const userId = req.firebaseUser!.uid;
    const journeys = await Journey.find({ userId })
      .sort({ startedAt: -1 }) // newest first
      .exec();

    res.json({
      success: true,
      journeys,
    });
  } catch (error) {
    console.error('[Journeys Route] Error fetching journeys:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch journeys' });
  }
});

export default router;
