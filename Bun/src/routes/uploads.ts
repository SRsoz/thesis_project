import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { Router } from "express";
import multer from "multer";
import { fileTypeFromBuffer } from "file-type";
import { prisma } from "../lib/prisma";

const router = Router();

export const uploadsDir = process.env.UPLOADS_DIR ?? path.resolve(process.cwd(), "uploads");
await mkdir(uploadsDir, { recursive: true });

const allowedMimeTypes = new Set([
  "image/png",
]);

const extensionByMimeType: Record<string, string> = {
  "image/png": "png",
};

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 1,
    fileSize: 20 * 1024 * 1024,
  },
});

router.post("/", upload.single("file"), async (req, res, next) => {
  try {
    if (!req.file) {
      res.status(400).json({ message: "No file was uploaded" });
      return;
    }

    const detectedType = await fileTypeFromBuffer(req.file.buffer);

    if (!detectedType || !allowedMimeTypes.has(detectedType.mime)) {
      res.status(415).json({ message: "Only png files allowed" });
      return;
    }

    const extension = extensionByMimeType[detectedType.mime];
    const fileName = `${randomUUID()}.${extension}`;
    const filePath = path.join(uploadsDir, fileName);

    await writeFile(filePath, req.file.buffer);

    const savedFile = await prisma.bunUpload.create({
      data: {
        originalName: req.file.originalname,
        fileName,
        mimeType: detectedType.mime,
        size: req.file.size,
      },
    });

    res.status(201).json({
      message: "Upload successful",
      file: {
        ...savedFile,
        url: `/uploads/${savedFile.fileName}`,
      },
    });
  } catch (error) {
    next(error);
  }
});

export default router;
