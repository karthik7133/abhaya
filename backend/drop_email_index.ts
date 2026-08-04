import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

async function run() {
  try {
    await mongoose.connect(process.env.MONGODB_URI as string);
    await mongoose.connection.collection('users').dropIndex('email_1');
    console.log("✅ Successfully dropped old email index.");
  } catch(e) {
    console.log("⚠️  Index not found or error dropping index (it may have already been dropped).", e);
  }
  process.exit(0);
}
run();
