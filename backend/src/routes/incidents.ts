import { Router, Request, Response } from 'express';
import multer from 'multer';
import { IncidentReport } from '../models';
import { authMiddleware } from '../middleware/auth';
import crypto from 'crypto';
import { uploadToCloudinary } from '../config/cloudinary';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } }); // 50MB limit

// ─── POST /api/incidents/report ───────────────────────────────────────────────
// Submit a new incident report

router.post('/report', authMiddleware, upload.single('media'), async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { category, severity, description, anonymous, notifyAuthorities } = req.body;
  
  let location;
  try {
    if (req.body.location) {
      location = typeof req.body.location === 'string' ? JSON.parse(req.body.location) : req.body.location;
    }
  } catch (e) {
    console.error('Invalid location JSON', req.body.location);
  }

  if (!category || !severity || !description) {
    res.status(400).json({ error: 'category, severity, and description are required' });
    return;
  }

  try {
    // Generate unique human-readable report ID: ABH-XXXXXXXX
    const reportId = `ABH-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

    let mediaUrl: string | undefined;

    if (req.file) {
      try {
        mediaUrl = await uploadToCloudinary(req.file.buffer, 'abhaya_incidents');
      } catch (uploadError) {
        console.error('[Incidents] Cloudinary upload error:', uploadError);
      }
    }

    const report = await IncidentReport.create({
      userId,
      reportId,
      category,
      severity,
      description,
      location,
      mediaUrl,
      anonymous:          anonymous === 'true' || anonymous === true,
      notifyAuthorities:  notifyAuthorities === 'true' || notifyAuthorities === true,
    });

    res.status(201).json({
      success: true,
      reportId: report.reportId,
      status: report.status,
      createdAt: report.createdAt,
    });
  } catch (err) {
    console.error('[Incidents] Report submission error:', err);
    res.status(500).json({ error: 'Failed to submit incident report' });
  }
});

// ─── GET /api/incidents/my-reports ────────────────────────────────────────────
// Get all reports by the authenticated user

router.get('/my-reports', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  try {
    const reports = await IncidentReport.find({ userId }).sort({ createdAt: -1 });
    res.json(reports);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch incident reports' });
  }
});

// ─── GET /api/incidents/:reportId ─────────────────────────────────────────────
// Get a single report by its human-readable ID

router.get('/:reportId', authMiddleware, async (req: Request, res: Response) => {
  const userId = req.firebaseUser!.uid;
  const { reportId } = req.params;
  try {
    const report = await IncidentReport.findOne({ reportId, userId });
    if (!report) {
      res.status(404).json({ error: 'Report not found' });
      return;
    }
    res.json(report);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch report' });
  }
});

export default router;
