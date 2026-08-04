import { Router, Request, Response } from 'express';
import { User } from '../models';
import { authMiddleware } from '../middleware/auth';
import { sendPushNotification } from '../config/firebase';

const router = Router();

// ─── POST /api/connections/request ───────────────────────────────────────────
// Send a connection request to another user (as guardian OR as child).
//
// role = 'guardian'  → "I want to GUARD this person"
// role = 'child'     → "I want this person to GUARD me"

router.post('/request', authMiddleware, async (req: Request, res: Response) => {
  const senderUid = req.firebaseUser!.uid;
  const { targetPhone, role } = req.body as { targetPhone: string; role: 'guardian' | 'child' };

  if (!targetPhone || !role) {
    res.status(400).json({ error: 'targetPhone and role are required' });
    return;
  }

  try {
    // Find both users
    const [sender, target] = await Promise.all([
      User.findOne({ uid: senderUid }),
      User.findOne({ phone: targetPhone }),
    ]);

    if (!sender) {
      res.status(404).json({ error: 'Your account not found. Call /users/sync first.' });
      return;
    }
    if (!target) {
      res.status(404).json({ error: 'Target user not found with that phone number.' });
      return;
    }
    if (target.uid === senderUid) {
      res.status(400).json({ error: 'Cannot send request to yourself.' });
      return;
    }

    // Check if already connected
    if (role === 'guardian') {
      if (target.guardianIds.includes(senderUid)) {
        res.status(409).json({ error: 'Already connected as guardian.' });
        return;
      }
    } else {
      if (target.childIds.includes(senderUid)) {
        res.status(409).json({ error: 'Already connected.' });
        return;
      }
    }

    // Check if pending request already exists
    const alreadyPending = target.pendingConnections.some(c => c.fromUid === senderUid);
    if (alreadyPending) {
      res.status(409).json({ error: 'A pending request already exists.' });
      return;
    }

    // Add to target's pending list
    await User.findOneAndUpdate(
      { uid: target.uid },
      {
        $push: {
          pendingConnections: {
            fromUid:   senderUid,
            fromName:  sender.displayName,
            fromPhoto: sender.photoUrl,
            role,
            sentAt:    new Date(),
          },
        },
      }
    );

    // Send push notification to target
    if (target.fcmToken) {
      const roleLabel = role === 'guardian'
        ? `${sender.displayName} wants to be your Guardian`
        : `${sender.displayName} wants you to be their Guardian`;
      await sendPushNotification({
        fcmToken: target.fcmToken,
        title:    '🛡️ Connection Request',
        body:     roleLabel,
        data:     { type: 'connection_request', fromUid: senderUid, role },
      });
    }

    res.json({ success: true, message: 'Connection request sent.' });
  } catch (err) {
    console.error('[Connections] request error:', err);
    res.status(500).json({ error: 'Failed to send request' });
  }
});

// ─── POST /api/connections/respond ───────────────────────────────────────────
// Accept or decline a connection request.

router.post('/respond', authMiddleware, async (req: Request, res: Response) => {
  const myUid = req.firebaseUser!.uid;
  const { fromUid, accept } = req.body as { fromUid: string; accept: boolean };

  if (!fromUid || accept === undefined) {
    res.status(400).json({ error: 'fromUid and accept (boolean) are required' });
    return;
  }

  try {
    const [me, requester] = await Promise.all([
      User.findOne({ uid: myUid }),
      User.findOne({ uid: fromUid }),
    ]);

    if (!me || !requester) {
      res.status(404).json({ error: 'User not found.' });
      return;
    }

    // Find the pending request
    const pendingReq = me.pendingConnections.find(c => c.fromUid === fromUid);
    if (!pendingReq) {
      res.status(404).json({ error: 'No pending request from this user.' });
      return;
    }

    // Remove from pending list regardless
    await User.findOneAndUpdate(
      { uid: myUid },
      { $pull: { pendingConnections: { fromUid } } }
    );

    if (accept) {
      // The requester's role tells us their relationship:
      // role = 'guardian' → requester guards me → add requester to MY guardianIds, add me to THEIR childIds
      // role = 'child'    → requester is my child → add requester to MY childIds, add me to THEIR guardianIds
      if (pendingReq.role === 'guardian') {
        await Promise.all([
          User.findOneAndUpdate({ uid: myUid },        { $addToSet: { guardianIds: fromUid } }),
          User.findOneAndUpdate({ uid: fromUid },      { $addToSet: { childIds: myUid } }),
        ]);
      } else {
        await Promise.all([
          User.findOneAndUpdate({ uid: myUid },        { $addToSet: { childIds: fromUid } }),
          User.findOneAndUpdate({ uid: fromUid },      { $addToSet: { guardianIds: myUid } }),
        ]);
      }

      // Notify requester of acceptance
      if (requester.fcmToken) {
        await sendPushNotification({
          fcmToken: requester.fcmToken,
          title:    '✅ Request Accepted',
          body:     `${me.displayName} accepted your connection request.`,
          data:     { type: 'connection_accepted', byUid: myUid },
        });
      }
    } else {
      // Notify requester of decline
      if (requester.fcmToken) {
        await sendPushNotification({
          fcmToken: requester.fcmToken,
          title:    '❌ Request Declined',
          body:     `${me.displayName} declined your connection request.`,
          data:     { type: 'connection_declined', byUid: myUid },
        });
      }
    }

    res.json({ success: true, accepted: accept });
  } catch (err) {
    console.error('[Connections] respond error:', err);
    res.status(500).json({ error: 'Failed to respond to request' });
  }
});

// ─── GET /api/connections/pending ────────────────────────────────────────────
// List all pending connection requests for the current user.

router.get('/pending', authMiddleware, async (req: Request, res: Response) => {
  try {
    const user = await User.findOne({ uid: req.firebaseUser!.uid }, { pendingConnections: 1 });
    res.json(user?.pendingConnections ?? []);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch pending requests' });
  }
});

// ─── GET /api/connections/my-network ─────────────────────────────────────────
// Returns full user details of all guardians and children.

router.get('/my-network', authMiddleware, async (req: Request, res: Response) => {
  try {
    const me = await User.findOne({ uid: req.firebaseUser!.uid });
    if (!me) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const [guardians, children] = await Promise.all([
      User.find(
        { uid: { $in: me.guardianIds } },
        { uid: 1, displayName: 1, email: 1, phone: 1, photoUrl: 1, fcmToken: 0 }
      ),
      User.find(
        { uid: { $in: me.childIds } },
        { uid: 1, displayName: 1, email: 1, phone: 1, photoUrl: 1, fcmToken: 0 }
      ),
    ]);

    res.json({ guardians, children });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch network' });
  }
});

// ─── DELETE /api/connections/remove ──────────────────────────────────────────
// Remove an existing connection (mutual unlink).

router.delete('/remove', authMiddleware, async (req: Request, res: Response) => {
  const myUid  = req.firebaseUser!.uid;
  const { targetUid } = req.body as { targetUid: string };

  if (!targetUid) {
    res.status(400).json({ error: 'targetUid is required' });
    return;
  }

  try {
    await Promise.all([
      User.findOneAndUpdate({ uid: myUid },     { $pull: { guardianIds: targetUid, childIds: targetUid } }),
      User.findOneAndUpdate({ uid: targetUid }, { $pull: { guardianIds: myUid,     childIds: myUid } }),
    ]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to remove connection' });
  }
});

export default router;
