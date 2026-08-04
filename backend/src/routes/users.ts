import { Router, Request, Response } from 'express';
import multer from 'multer';
import { User, Message, EmergencyEvent, LiveLocation, MoodTrend, IncidentReport, Journey } from '../models';
import { authMiddleware } from '../middleware/auth';
import { uploadToCloudinary } from '../config/cloudinary';
import { getFirebaseAdmin } from '../config/firebase';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } }); // 5MB

// ─── POST /api/users/sync ─────────────────────────────────────────────────────
// Called on app start: creates or updates the user record with their FCM token.

router.post('/sync', authMiddleware, async (req: Request, res: Response) => {
  const { uid, email: fbEmail, picture, name: fbName } = req.firebaseUser!;
  const { fcmToken, phone, name, email: bodyEmail, age, gender } = req.body as { fcmToken?: string; phone?: string; name?: string; email?: string; age?: number; gender?: string };
  const email = bodyEmail || fbEmail;

  try {
    const updatePayload: Record<string, any> = {};
    if (name) updatePayload.displayName = name;
    else if (fbName) updatePayload.displayName = fbName;
    
    if (email) updatePayload.email = email;
    if (picture) updatePayload.photoUrl = picture;
    if (fcmToken) updatePayload.fcmToken = fcmToken;
    if (phone) updatePayload.phone = phone;
    if (age !== undefined) updatePayload.age = age;
    if (gender) updatePayload.gender = gender;

    const setOnInsertPayload: Record<string, any> = { uid };
    if (!updatePayload.displayName) {
      setOnInsertPayload.displayName = 'Abhaya User';
    }

    const user = await User.findOneAndUpdate(
      { uid },
      {
        $set: updatePayload,
        $setOnInsert: setOnInsertPayload,
      },
      { upsert: true, new: true, runValidators: true }
    );
    res.json({ success: true, user });
  } catch (err) {
    console.error('[Users] sync error:', err);
    res.status(500).json({ error: 'Failed to sync user' });
  }
});

// ─── GET /api/users/me ────────────────────────────────────────────────────────

router.get('/me', authMiddleware, async (req: Request, res: Response) => {
  try {
    const user = await User.findOne({ uid: req.firebaseUser!.uid });
    if (!user) {
      res.status(404).json({ error: 'User not found. Call /sync first.' });
      return;
    }
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// ─── PUT /api/users/settings ──────────────────────────────────────────────────

router.put('/settings', authMiddleware, async (req: Request, res: Response) => {
  const { settings } = req.body as { settings: Partial<{
    backgroundSensing: boolean;
    moodSharingWithGuardians: boolean;
    dataRetentionDays: number;
    notifyGuardianOnCrisisChat: boolean;
  }> };

  if (!settings || typeof settings !== 'object') {
    res.status(400).json({ error: 'settings object is required' });
    return;
  }

  // Use dot-notation so only provided fields are updated (no overwrite of others)
  const dotNotationUpdate: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(settings)) {
    dotNotationUpdate[`settings.${key}`] = value;
  }

  try {
    const user = await User.findOneAndUpdate(
      { uid: req.firebaseUser!.uid },
      { $set: dotNotationUpdate },
      { new: true }
    );
    res.json({ success: true, settings: user?.settings });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update settings' });
  }
});

// ─── POST /api/users/avatar ───────────────────────────────────────────────────
// Upload profile picture to Cloudinary.

router.post(
  '/avatar',
  authMiddleware,
  upload.single('avatar'),
  async (req: Request, res: Response) => {
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }
    try {
      const uid = req.firebaseUser!.uid;
      const url = await uploadToCloudinary(
        req.file.buffer,
        'abhaya/avatars',
        `avatar_${uid}`
      );
      await User.findOneAndUpdate({ uid }, { $set: { photoUrl: url } });
      res.json({ success: true, photoUrl: url });
    } catch (err) {
      console.error('[Users] Avatar upload error:', err);
      res.status(500).json({ error: 'Avatar upload failed' });
    }
  }
);

// ─── GET /api/users/search?q=email ───────────────────────────────────────────
// Search for another user by email to invite them as guardian/child.

router.get('/search', authMiddleware, async (req: Request, res: Response) => {
  const q = (req.query['q'] as string ?? '').trim().toLowerCase();
  if (!q || q.length < 3) {
    res.status(400).json({ error: 'Query must be at least 3 characters' });
    return;
  }
  try {
    const users = await User.find(
      { email: { $regex: q, $options: 'i' }, uid: { $ne: req.firebaseUser!.uid } },
      { uid: 1, displayName: 1, email: 1, photoUrl: 1 }
    ).limit(10);
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: 'Search failed' });
  }
});

// ─── POST /api/users/fcm-token ────────────────────────────────────────────────

router.post('/fcm-token', authMiddleware, async (req: Request, res: Response) => {
  const { fcmToken } = req.body as { fcmToken: string };
  if (!fcmToken) {
    res.status(400).json({ error: 'fcmToken is required' });
    return;
  }
  try {
    await User.findOneAndUpdate({ uid: req.firebaseUser!.uid }, { $set: { fcmToken } });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update FCM token' });
  }
});

// ─── DELETE /api/users/me ─────────────────────────────────────────────────────

router.delete('/me', authMiddleware, async (req: Request, res: Response) => {
  const uid = req.firebaseUser!.uid;
  try {
    // 1. Delete user from Firebase Auth
    await getFirebaseAdmin().auth().deleteUser(uid);

    // 2. Delete all related data from MongoDB
    await Promise.all([
      User.deleteOne({ uid }),
      Message.deleteMany({ userId: uid }),
      EmergencyEvent.deleteMany({ userId: uid }),
      LiveLocation.deleteOne({ userId: uid }),
      MoodTrend.deleteMany({ userId: uid }),
      IncidentReport.deleteMany({ userId: uid }),
      Journey.deleteMany({ userId: uid }),
    ]);

    res.json({ success: true, message: 'Account and all related data successfully deleted.' });
  } catch (err) {
    console.error('[Users] Account deletion error:', err);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// ─── POST /api/users/check-phone ──────────────────────────────────────────────
// Check if a user exists in Firebase Auth by phone number. Public endpoint.

router.post('/check-phone', async (req: Request, res: Response) => {
  const { phone } = req.body;
  if (!phone) {
    res.status(400).json({ error: 'Phone number is required' });
    return;
  }
  try {
    await getFirebaseAdmin().auth().getUserByPhoneNumber(phone);
    res.json({ exists: true });
  } catch (err: any) {
    if (err.code === 'auth/user-not-found') {
      res.json({ exists: false });
    } else {
      console.error('[Users] check-phone error:', err);
      res.status(500).json({ error: 'Failed to check phone number' });
    }
  }
});

export default router;
