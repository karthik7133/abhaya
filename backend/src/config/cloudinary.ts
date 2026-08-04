import { v2 as cloudinary } from 'cloudinary';
import dotenv from 'dotenv';

dotenv.config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key:    process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
  secure:     true,
});

export { cloudinary };

/**
 * Upload a buffer to Cloudinary and return the secure URL.
 * @param buffer   - File buffer
 * @param folder   - Cloudinary folder (e.g., 'abhaya/avatars', 'abhaya/evidence')
 * @param publicId - Optional public ID
 */
export async function uploadToCloudinary(
  buffer: Buffer,
  folder: string,
  publicId?: string
): Promise<string> {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        public_id:        publicId,
        resource_type:    'auto',
        transformation:   folder.includes('avatar') 
          ? [{ width: 400, height: 400, crop: 'fill', quality: 'auto' }]
          : undefined,
      },
      (error, result) => {
        if (error || !result) {
          reject(error ?? new Error('Cloudinary upload failed'));
        } else {
          resolve(result.secure_url);
        }
      }
    );
    stream.end(buffer);
  });
}

/**
 * Delete an asset from Cloudinary by public_id.
 */
export async function deleteFromCloudinary(publicId: string): Promise<void> {
  await cloudinary.uploader.destroy(publicId);
}
