import { Router, Request, Response } from 'express';
import { LiveLocation, User } from '../models';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// ─── POST /api/location/update ────────────────────────────────────────────────
// Called periodically by the background service to update current location.

router.post('/update', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { lat, lng, speed, accuracy, altitude, isGuardianActive } = req.body as {
    lat: number;
    lng: number;
    speed?: number;
    accuracy?: number;
    altitude?: number;
    isGuardianActive?: boolean;
  };

  if (lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'lat and lng are required' });
    return;
  }

  try {
    await LiveLocation.findOneAndUpdate(
      { userId },
      {
        $set: {
          lat,
          lng,
          ...(speed !== undefined && { speed }),
          ...(accuracy !== undefined && { accuracy }),
          ...(altitude !== undefined && { altitude }),
          ...(isGuardianActive !== undefined && { isGuardianActive }),
        },
      },
      { upsert: true }
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update location' });
  }
});

// ─── GET /api/location/feed ───────────────────────────────────────────────────
// Returns live locations for all users in the current user's childIds list
// (i.e. the people this user is guarding).
// In a real production app with websockets, this would be a socket stream.
// Here we use a polling endpoint for simplicity.

router.get('/feed', authMiddleware, async (req: Request, res: Response) => {
  const myUid = req.firebaseUser!.uid;

  try {
    const me = await User.findOne({ uid: myUid });
    if (!me || me.childIds.length === 0) {
      res.json([]);
      return;
    }

    // Get live locations of all children who have guardian active OR an active alert
    // Actually, let's just return all their current known locations and let the client decide
    const locations = await LiveLocation.find({ userId: { $in: me.childIds } });
    
    // Also attach basic user info to the location payload
    const children = await User.find(
      { uid: { $in: me.childIds } }, 
      { uid: 1, displayName: 1, photoUrl: 1, phone: 1 }
    );

    const feed = locations.map(loc => {
      const child = children.find(c => c.uid === loc.userId);
      return {
        userId: loc.userId,
        name: child?.displayName,
        photoUrl: child?.photoUrl,
        phone: child?.phone,
        lat: loc.lat,
        lng: loc.lng,
        speed: loc.speed,
        threatScore: loc.threatScore,
        isGuardianActive: loc.isGuardianActive,
        updatedAt: loc.updatedAt,
      };
    });

    res.json(feed);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch location feed' });
  }
});

export default router;
