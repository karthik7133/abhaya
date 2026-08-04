import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import mongoose from "mongoose";

admin.initializeApp();

let isConnected = false;

async function connectToMongo() {
  if (isConnected) return;
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error("MONGODB_URI environment variable is not set");
  }
  await mongoose.connect(mongoUri);
  isConnected = true;
  console.log("✅ Connected to MongoDB Atlas");
}

export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  console.log(`[onUserDeleted] User ${uid} was deleted in Firebase. Initiating cleanup...`);

  try {
    await connectToMongo();
    const db = mongoose.connection.db;
    if (!db) {
      throw new Error("MongoDB database is not available");
    }

    // Perform cascade delete across all relevant collections
    const collections = [
      { name: "users", query: { uid } },
      { name: "messages", query: { userId: uid } },
      { name: "emergencyevents", query: { userId: uid } },
      { name: "livelocations", query: { userId: uid } },
      { name: "moodtrends", query: { userId: uid } },
      { name: "incidentreports", query: { userId: uid } },
      { name: "journeys", query: { userId: uid } },
    ];

    const promises = collections.map(async (col) => {
      const result = await db.collection(col.name).deleteMany(col.query);
      console.log(`Deleted ${result.deletedCount} documents from ${col.name}`);
    });

    await Promise.all(promises);
    console.log(`✅ Successfully cleaned up data for user ${uid}.`);
  } catch (error) {
    console.error(`❌ Error cleaning up data for user ${uid}:`, error);
  }
});
