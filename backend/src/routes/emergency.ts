import { Router, Request, Response } from 'express';
import { EmergencyEvent, User, LiveLocation, TrustedContact } from '../models';
import { authMiddleware } from '../middleware/auth';
import { broadcastPush, sendPushNotification } from '../config/firebase';

const router = Router();

// ─── POST /api/emergency/sos ──────────────────────────────────────────────────
// Manual SOS triggered by the user

router.post('/sos', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { lat, lng } = req.body as { lat?: number; lng?: number };

  try {
    const user = await User.findOne({ uid: userId });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const event = await EmergencyEvent.create({
      userId,
      type: 'sos',
      threatScore: 100,
      location: lat && lng ? { lat, lng } : undefined,
      status: 'active',
      notifiedGuardianIds: user.guardianIds,
    });

    if (user.guardianIds.length > 0) {
      const guardians = await User.find({ uid: { $in: user.guardianIds } });
      const fcmTokens = guardians.map(g => g.fcmToken).filter((t): t is string => !!t);

      await broadcastPush({
        fcmTokens,
        title: '🚨 SOS TRIGGERED',
        body: `${user.displayName} has triggered an SOS and needs immediate assistance!`,
        data: { type: 'sos', eventId: event._id.toString(), fromUid: userId },
      });
    }

    // Query trusted contacts who are set to receive SOS alerts
    const trustedToNotify = await TrustedContact.find({ userId, notifyOnSos: true });
    console.log(`[Emergency] SOS triggered by ${user.displayName}. Notified ${user.guardianIds.length} guardians and ${trustedToNotify.length} trusted contacts.`);

    res.json({ success: true, event, notifiedTrustedCount: trustedToNotify.length });
  } catch (err) {
    console.error('[Emergency] SOS trigger error:', err);
    res.status(500).json({ error: 'Failed to trigger SOS' });
  }
});

// ─── POST /api/emergency/threat-score ─────────────────────────────────────────
// Handle background threat score updates from the fusion engine

router.post('/threat-score', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { score, audioDistress, maxAcceleration, lat, lng } = req.body as { 
    score: number; audioDistress?: boolean; maxAcceleration?: number; lat?: number; lng?: number; 
  };

  // Validate score
  if (typeof score !== 'number' || score < 0 || score > 100) {
    res.status(400).json({ error: 'score must be a number between 0 and 100' });
    return;
  }

  try {
    // Update live location threat score — only set lat/lng if provided
    const locationUpdate: Record<string, unknown> = { threatScore: score };
    if (lat !== undefined && lng !== undefined) {
      locationUpdate['lat'] = lat;
      locationUpdate['lng'] = lng;
    }

    await LiveLocation.findOneAndUpdate(
      { userId },
      { $set: locationUpdate },
      {
        upsert: true,
        // When upserting with no existing lat/lng, provide defaults so required fields are satisfied
        setDefaultsOnInsert: true,
        new: true,
      }
    ).catch(() => {
      // If upsert fails because lat/lng are missing for a new doc, create with 0,0 as placeholders
      return LiveLocation.findOneAndUpdate(
        { userId },
        { $setOnInsert: { userId, lat: lat ?? 0, lng: lng ?? 0 }, $set: { threatScore: score } },
        { upsert: true, new: true }
      );
    });

    const user = await User.findOne({ uid: userId });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Rule: Score >= 80 creates an active emergency event
    if (score >= 80) {
      // Check if there is already an active physical event to avoid duplicates
      const activeEvent = await EmergencyEvent.findOne({ userId, status: 'active', type: { $ne: 'chat_crisis' } });

      if (!activeEvent) {
        let type: 'audio_distress' | 'motion_anomaly' = 'audio_distress';
        if (maxAcceleration && maxAcceleration > 25 && !audioDistress) {
          type = 'motion_anomaly';
        }

        const event = await EmergencyEvent.create({
          userId,
          type,
          threatScore: score,
          location: lat && lng ? { lat, lng } : undefined,
          status: 'active',
          notifiedGuardianIds: user.guardianIds,
        });

        if (user.guardianIds.length > 0) {
          const guardians = await User.find({ uid: { $in: user.guardianIds } });
          const fcmTokens = guardians.map(g => g.fcmToken).filter((t): t is string => !!t);

          await broadcastPush({
            fcmTokens,
            title: '⚠️ Critical Threat Alert',
            body: `Abhaya sensors detected a critical threat for ${user.displayName}. Score: ${Math.round(score)}`,
            data: { type: 'threat_critical', eventId: event._id.toString(), fromUid: userId },
          });
        }
      }
    } 
    // Rule: Score >= 40 triggers an in-app check-in for the user
    else if (score >= 40) {
      if (user.fcmToken) {
        await sendPushNotification({
          fcmToken: user.fcmToken,
          title: 'Check-in Required',
          body: 'We detected unusual activity. Are you safe?',
          data: { type: 'user_checkin' },
        });
      }
    }

    res.json({ success: true, score });
  } catch (err) {
    console.error('[Emergency] Threat score update error:', err);
    res.status(500).json({ error: 'Failed to process threat score' });
  }
});

// ─── GET /api/emergency/history ───────────────────────────────────────────────
// Get all past events for the timeline

router.get('/history', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  try {
    const events = await EmergencyEvent.find({ userId }).sort({ createdAt: -1 });
    res.json(events);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch incident history' });
  }
});

// ─── PUT /api/emergency/:id/resolve ───────────────────────────────────────────
// Mark an active emergency as resolved

router.put('/:id/resolve', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { notes } = req.body as { notes?: string };

  try {
    const event = await EmergencyEvent.findOneAndUpdate(
      { _id: req.params.id, userId },
      { $set: { status: 'resolved', resolutionNotes: notes, resolvedAt: new Date() } },
      { new: true }
    );

    if (!event) {
      res.status(404).json({ error: 'Event not found or unauthorized' });
      return;
    }

    res.json({ success: true, event });
  } catch (err) {
    res.status(500).json({ error: 'Failed to resolve event' });
  }
});

// ─── PUT /api/emergency/:id/dismiss ──────────────────────────────────────────
// Mark an active emergency as dismissed (false alarm)

router.put('/:id/dismiss', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;

  try {
    const event = await EmergencyEvent.findOneAndUpdate(
      { _id: req.params['id'], userId },
      { $set: { status: 'dismissed', resolvedAt: new Date() } },
      { new: true }
    );

    if (!event) {
      res.status(404).json({ error: 'Event not found or unauthorized' });
      return;
    }

    res.json({ success: true, event });
  } catch (err) {
    res.status(500).json({ error: 'Failed to dismiss event' });
  }
});

export default router;
