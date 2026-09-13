import { Router, Request, Response } from 'express';
import { DeviceContact, TrustedContact, User } from '../models';
import { authMiddleware } from '../middleware/auth';

const router = Router();

// Helper to clean and normalize phone numbers
function normalizePhone(raw: string): string {
  return raw.replace(/[\s\-\(\)\.]/g, '').trim();
}

// ─── POST /api/contacts/sync ──────────────────────────────────────────────────
// Bulk upload and sync device contacts for the authenticated user
router.post('/sync', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const rawContacts = req.body.contacts;

  if (!Array.isArray(rawContacts)) {
    res.status(400).json({ error: 'contacts must be an array' });
    return;
  }

  try {
    // Resolve user's display name
    const userDoc = await User.findOne({ uid: userId });
    const userName =
      userDoc?.displayName ||
      req.firebaseUser?.name ||
      (req.body.userName as string) ||
      'Abhaya User';

    const contactsToInsert: Array<{
      userId: string;
      userName: string;
      name: string;
      phoneNumbers: string[];
      primaryPhone: string;
      emails: string[];
      deviceContactId?: string;
      uploadedAt: Date;
    }> = [];

    for (const c of rawContacts) {
      const name = (c.name || '').trim();
      const rawPhones: string[] = Array.isArray(c.phoneNumbers)
        ? c.phoneNumbers
        : Array.isArray(c.phones)
        ? c.phones
        : [];

      const cleanPhones = rawPhones
        .map((p: any) => (typeof p === 'string' ? normalizePhone(p) : typeof p?.number === 'string' ? normalizePhone(p.number) : ''))
        .filter((p: string) => p.length >= 3);

      if (!name && cleanPhones.length === 0) continue;

      const primaryPhone = cleanPhones[0] || '';
      if (!primaryPhone) continue; // Must have at least one phone number

      const rawEmails: string[] = Array.isArray(c.emails)
        ? c.emails.map((e: any) => (typeof e === 'string' ? e.trim() : typeof e?.address === 'string' ? e.address.trim() : ''))
        : [];

      contactsToInsert.push({
        userId,
        userName,
        name: name || primaryPhone,
        phoneNumbers: Array.from(new Set(cleanPhones)),
        primaryPhone,
        emails: rawEmails.filter(Boolean),
        deviceContactId: c.deviceContactId || c.id,
        uploadedAt: new Date(),
      });
    }

    // Refresh user's phonebook in MongoDB: delete existing for this user, then insert new batch
    await DeviceContact.deleteMany({ userId });
    if (contactsToInsert.length > 0) {
      await DeviceContact.insertMany(contactsToInsert, { ordered: false });
    }

    console.log(`[Contacts] Synced ${contactsToInsert.length} contacts for user ${userName} (${userId})`);

    res.json({
      success: true,
      count: contactsToInsert.length,
      userName,
      message: `Successfully uploaded and synced ${contactsToInsert.length} contacts`,
    });
  } catch (err: any) {
    console.error('[Contacts] Error syncing contacts:', err);
    res.status(500).json({ error: 'Failed to sync contacts', details: err.message });
  }
});

// ─── GET /api/contacts ────────────────────────────────────────────────────────
// Retrieve all device contacts uploaded for this user (with optional search query)
router.get('/', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const q = (req.query.q as string)?.trim();
  const limit = Math.min(Number(req.query.limit) || 200, 1000);

  try {
    const filter: Record<string, any> = { userId };
    if (q) {
      filter.$or = [
        { name: { $regex: q, $options: 'i' } },
        { primaryPhone: { $regex: q, $options: 'i' } },
        { phoneNumbers: { $regex: q, $options: 'i' } },
      ];
    }

    const contacts = await DeviceContact.find(filter)
      .sort({ name: 1 })
      .limit(limit);

    res.json({ contacts, total: contacts.length });
  } catch (err) {
    console.error('[Contacts] Error fetching contacts:', err);
    res.status(500).json({ error: 'Failed to retrieve contacts' });
  }
});

// ─── GET /api/contacts/trusted ────────────────────────────────────────────────
// Retrieve all user-selected trusted emergency contacts
router.get('/trusted', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;

  try {
    const trustedContacts = await TrustedContact.find({ userId }).sort({ createdAt: -1 });
    res.json({ trustedContacts });
  } catch (err) {
    console.error('[Contacts] Error fetching trusted contacts:', err);
    res.status(500).json({ error: 'Failed to retrieve trusted contacts' });
  }
});

// ─── POST /api/contacts/trusted ───────────────────────────────────────────────
// Add or update a contact in the trusted contacts collection
router.post('/trusted', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { name, phone, relationship, notifyOnSos, notifyOnThreat, notifyOnNightMode } = req.body;

  if (!phone || !name) {
    res.status(400).json({ error: 'name and phone are required' });
    return;
  }

  const cleanPhone = normalizePhone(phone);

  try {
    const userDoc = await User.findOne({ uid: userId });
    const userName = userDoc?.displayName || req.firebaseUser?.name || 'User';

    const trusted = await TrustedContact.findOneAndUpdate(
      { userId, phone: cleanPhone },
      {
        $set: {
          userName,
          name: name.trim(),
          phone: cleanPhone,
          relationship: relationship || 'Emergency Contact',
          notifyOnSos: notifyOnSos !== undefined ? !!notifyOnSos : true,
          notifyOnThreat: notifyOnThreat !== undefined ? !!notifyOnThreat : true,
          notifyOnNightMode: notifyOnNightMode !== undefined ? !!notifyOnNightMode : true,
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.json({ success: true, contact: trusted });
  } catch (err) {
    console.error('[Contacts] Error adding trusted contact:', err);
    res.status(500).json({ error: 'Failed to save trusted contact' });
  }
});

// ─── PUT /api/contacts/trusted/:id ────────────────────────────────────────────
// Update notification preferences or details for a trusted contact
router.put('/trusted/:id', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { id } = req.params;
  const { name, phone, relationship, notifyOnSos, notifyOnThreat, notifyOnNightMode } = req.body;

  try {
    const update: Record<string, any> = {};
    if (name) update.name = name.trim();
    if (phone) update.phone = normalizePhone(phone);
    if (relationship !== undefined) update.relationship = relationship;
    if (notifyOnSos !== undefined) update.notifyOnSos = !!notifyOnSos;
    if (notifyOnThreat !== undefined) update.notifyOnThreat = !!notifyOnThreat;
    if (notifyOnNightMode !== undefined) update.notifyOnNightMode = !!notifyOnNightMode;

    const contact = await TrustedContact.findOneAndUpdate(
      { _id: id, userId },
      { $set: update },
      { new: true }
    );

    if (!contact) {
      res.status(404).json({ error: 'Trusted contact not found' });
      return;
    }

    res.json({ success: true, contact });
  } catch (err) {
    console.error('[Contacts] Error updating trusted contact:', err);
    res.status(500).json({ error: 'Failed to update trusted contact' });
  }
});

// ─── DELETE /api/contacts/trusted/:id ─────────────────────────────────────────
// Delete a trusted contact by ID
router.delete('/trusted/:id', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { id } = req.params;

  try {
    const result = await TrustedContact.findOneAndDelete({ _id: id, userId });
    if (!result) {
      res.status(404).json({ error: 'Trusted contact not found' });
      return;
    }

    res.json({ success: true, message: 'Trusted contact removed' });
  } catch (err) {
    console.error('[Contacts] Error deleting trusted contact:', err);
    res.status(500).json({ error: 'Failed to delete trusted contact' });
  }
});

// ─── DELETE /api/contacts/trusted/by-phone/:phone ─────────────────────────────
// Delete a trusted contact by phone number
router.delete('/trusted/by-phone/:phone', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const cleanPhone = normalizePhone(req.params.phone);

  try {
    await TrustedContact.deleteMany({ userId, phone: cleanPhone });
    res.json({ success: true, message: 'Trusted contact removed by phone' });
  } catch (err) {
    console.error('[Contacts] Error deleting trusted contact by phone:', err);
    res.status(500).json({ error: 'Failed to delete trusted contact' });
  }
});

export default router;
