import mongoose, { Schema, Document, Types } from 'mongoose';

// ─── User ─────────────────────────────────────────────────────────────────────

export interface IUser extends Document {
  _id: Types.ObjectId;
  uid: string;           // Firebase UID
  displayName: string;
  email?: string;
  age?: number;
  gender?: string;
  phone?: string;
  photoUrl?: string;     // Cloudinary URL
  fcmToken?: string;
  guardianIds: string[]; // Firebase UIDs of guardians who watch this user
  childIds: string[];    // Firebase UIDs of children this user guards
  pendingConnections: IPendingConnection[];
  settings: {
    backgroundSensing: boolean;
    moodSharingWithGuardians: boolean;
    dataRetentionDays: number;
    notifyGuardianOnCrisisChat: boolean;
  };
  createdAt: Date;
  updatedAt: Date;
}

interface IPendingConnection {
  fromUid: string;
  fromName: string;
  fromPhoto?: string;
  role: 'guardian' | 'child'; // role of the requester
  sentAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    uid:         { type: String, required: true, unique: true, index: true },
    displayName: { type: String, required: true },
    email:       { type: String, sparse: true, unique: true },
    age:         { type: Number },
    gender:      { type: String },
    phone:       { type: String },
    photoUrl:    { type: String },
    fcmToken:    { type: String },
    guardianIds: { type: [String], default: [] },
    childIds:    { type: [String], default: [] },
    pendingConnections: [{
      fromUid:   String,
      fromName:  String,
      fromPhoto: String,
      role:      { type: String, enum: ['guardian', 'child'] },
      sentAt:    { type: Date, default: Date.now },
    }],
    settings: {
      backgroundSensing:              { type: Boolean, default: true },
      moodSharingWithGuardians:       { type: Boolean, default: true },
      dataRetentionDays:              { type: Number, default: 30 },
      notifyGuardianOnCrisisChat:     { type: Boolean, default: false },
    },
  },
  { timestamps: true }
);

export const User = mongoose.model<IUser>('User', UserSchema);

// ─── Chat Message ─────────────────────────────────────────────────────────────

export interface IMessage extends Document {
  userId: string;        // Firebase UID of the user
  text: string;
  isUser: boolean;       // true = user's message, false = AI reply
  riskLevel: 'low' | 'moderate' | 'high';
  crisisResourcesShown: boolean;
  sentAt: Date;
}

const MessageSchema = new Schema<IMessage>({
  userId:               { type: String, required: true, index: true },
  text:                 { type: String, required: true },
  isUser:               { type: Boolean, required: true },
  riskLevel:            { type: String, enum: ['low', 'moderate', 'high'], default: 'low' },
  crisisResourcesShown: { type: Boolean, default: false },
  sentAt:               { type: Date, default: Date.now },
});

export const Message = mongoose.model<IMessage>('Message', MessageSchema);

// ─── Emergency Event ──────────────────────────────────────────────────────────

export interface IEmergencyEvent extends Document {
  userId: string;
  type: 'sos' | 'audio_distress' | 'motion_anomaly' | 'chat_crisis';
  threatScore?: number;
  location?: {
    lat: number;
    lng: number;
    speed?: number;
  };
  audioEvidenceUrl?: string;
  status: 'active' | 'resolved' | 'dismissed';
  notifiedGuardianIds: string[];
  resolutionNotes?: string;
  createdAt: Date;
  resolvedAt?: Date;
}

const EmergencyEventSchema = new Schema<IEmergencyEvent>(
  {
    userId:               { type: String, required: true, index: true },
    type:                 { type: String, enum: ['sos', 'audio_distress', 'motion_anomaly', 'chat_crisis'], required: true },
    threatScore:          { type: Number },
    location: {
      lat:   Number,
      lng:   Number,
      speed: Number,
    },
    audioEvidenceUrl:     { type: String },
    status:               { type: String, enum: ['active', 'resolved', 'dismissed'], default: 'active' },
    notifiedGuardianIds:  { type: [String], default: [] },
    resolutionNotes:      { type: String },
    resolvedAt:           { type: Date },
  },
  { timestamps: true }
);

export const EmergencyEvent = mongoose.model<IEmergencyEvent>('EmergencyEvent', EmergencyEventSchema);

// ─── Live Location ────────────────────────────────────────────────────────────

export interface ILiveLocation extends Document {
  userId: string;
  lat: number;
  lng: number;
  speed?: number;
  accuracy?: number;
  altitude?: number;
  threatScore: number;
  isGuardianActive: boolean;
  updatedAt: Date;
}

const LiveLocationSchema = new Schema<ILiveLocation>(
  {
    userId:           { type: String, required: true, unique: true, index: true },
    lat:              { type: Number, required: true },
    lng:              { type: Number, required: true },
    speed:            { type: Number },
    accuracy:         { type: Number },
    altitude:         { type: Number },
    threatScore:      { type: Number, default: 0 },
    isGuardianActive: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export const LiveLocation = mongoose.model<ILiveLocation>('LiveLocation', LiveLocationSchema);

// ─── Mood Trend ───────────────────────────────────────────────────────────────

export interface IMoodTrend extends Document {
  userId: string;
  date: string; // YYYY-MM-DD
  avgRiskLevel: 'low' | 'moderate' | 'high';
  messageCount: number;
  crisisTriggered: boolean;
}

const MoodTrendSchema = new Schema<IMoodTrend>({
  userId:           { type: String, required: true, index: true },
  date:             { type: String, required: true },
  avgRiskLevel:     { type: String, enum: ['low', 'moderate', 'high'], default: 'low' },
  messageCount:     { type: Number, default: 0 },
  crisisTriggered:  { type: Boolean, default: false },
});

MoodTrendSchema.index({ userId: 1, date: 1 }, { unique: true });

export const MoodTrend = mongoose.model<IMoodTrend>('MoodTrend', MoodTrendSchema);

// ─── Incident Report ──────────────────────────────────────────────────────────

export interface IIncidentReport extends Document {
  userId: string;
  reportId: string;        // Human-readable ID: ABH-XXXXXXXX
  category: string;        // 'harassment' | 'stalking' | 'theft' | 'assault' | 'unsafe_area' | 'suspicious' | 'other'
  severity: string;        // 'low' | 'medium' | 'high' | 'critical'
  description: string;
  location?: { lat: number; lng: number };
  anonymous: boolean;
  notifyAuthorities: boolean;
  status: 'submitted' | 'under_review' | 'resolved';
  mediaUrl?: string;
  createdAt: Date;
}

const IncidentReportSchema = new Schema<IIncidentReport>(
  {
    userId:             { type: String, required: true, index: true },
    reportId:           { type: String, required: true, unique: true, index: true },
    category:           { type: String, required: true },
    severity:           { type: String, enum: ['low', 'medium', 'high', 'critical'], required: true },
    description:        { type: String, required: true },
    location:           { lat: Number, lng: Number },
    anonymous:          { type: Boolean, default: false },
    notifyAuthorities:  { type: Boolean, default: false },
    status:             { type: String, enum: ['submitted', 'under_review', 'resolved'], default: 'submitted' },
    mediaUrl:           { type: String },
  },
  { timestamps: true }
);

export const IncidentReport = mongoose.model<IIncidentReport>('IncidentReport', IncidentReportSchema);
// ─── Journey ──────────────────────────────────────────────────────────────────

export interface IJourney extends Document {
  userId: string;        // Firebase UID
  destination: string;
  startedAt: Date;
  arrivedAt: Date;
  durationSeconds: number;
  distanceMeters: number;
  checkInsCount: number;
  safetyScore: number;
  nightModeActive: boolean;
  routeType: string;
  waypoints: Array<{ lat: number; lng: number; time: string }>;
}

const JourneySchema = new Schema<IJourney>(
  {
    userId:          { type: String, required: true, index: true },
    destination:     { type: String, required: true },
    startedAt:       { type: Date, required: true },
    arrivedAt:       { type: Date, required: true },
    durationSeconds: { type: Number, required: true },
    distanceMeters:  { type: Number, required: true },
    checkInsCount:   { type: Number, required: true },
    safetyScore:     { type: Number, required: true },
    nightModeActive: { type: Boolean, default: false },
    routeType:       { type: String, required: true },
    waypoints:       [{ 
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      time: { type: String, required: true }
    }],
  },
  { timestamps: true }
);

export const Journey = mongoose.model<IJourney>('Journey', JourneySchema);
