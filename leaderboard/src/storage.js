import { randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { PutObjectCommand, GetObjectCommand, S3Client } from "@aws-sdk/client-s3";

const MAX_BYTES = 8 * 1024 * 1024;
const ALLOWED = new Set(["image/png", "image/jpeg", "image/jpg", "image/webp"]);

export function createStorage() {
  const bucket = process.env.AWS_S3_BUCKET_NAME;
  const endpoint = process.env.AWS_ENDPOINT_URL;
  const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
  const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

  if (bucket && endpoint && accessKeyId && secretAccessKey) {
    const client = new S3Client({
      region: process.env.AWS_DEFAULT_REGION || "auto",
      endpoint,
      credentials: { accessKeyId, secretAccessKey },
      forcePathStyle: process.env.AWS_S3_URL_STYLE === "path",
    });
    return {
      async put(bytes, contentType) {
        const key = `${randomUUID()}${extensionFor(contentType)}`;
        await client.send(
          new PutObjectCommand({
            Bucket: bucket,
            Key: key,
            Body: bytes,
            ContentType: contentType,
          }),
        );
        return key;
      },
      async get(key) {
        const result = await client.send(
          new GetObjectCommand({ Bucket: bucket, Key: key }),
        );
        const chunks = [];
        for await (const chunk of result.Body) chunks.push(chunk);
        return {
          bytes: Buffer.concat(chunks),
          contentType: result.ContentType || "application/octet-stream",
        };
      },
    };
  }

  const dir = path.resolve("data/uploads");
  return {
    async put(bytes, contentType) {
      await mkdir(dir, { recursive: true });
      const key = `${randomUUID()}${extensionFor(contentType)}`;
      await writeFile(path.join(dir, key), bytes);
      return key;
    },
    async get(key) {
      const bytes = await readFile(path.join(dir, key));
      return { bytes, contentType: contentTypeFor(key) };
    },
  };
}

export function validateImage(file) {
  if (!file || typeof file === "string") {
    return "Choose a screenshot of your app window.";
  }
  const type = (file.type || "").toLowerCase();
  if (!ALLOWED.has(type)) {
    return "Use a PNG or JPEG screenshot of the app window.";
  }
  if (file.size > MAX_BYTES) {
    return "That screenshot is too large — keep it under 8 MB.";
  }
  return null;
}

function extensionFor(contentType) {
  if (contentType === "image/png") return ".png";
  if (contentType === "image/webp") return ".webp";
  return ".jpg";
}

function contentTypeFor(key) {
  if (key.endsWith(".png")) return "image/png";
  if (key.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}
