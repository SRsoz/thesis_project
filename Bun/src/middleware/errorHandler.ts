import type { ErrorRequestHandler } from "express";
import multer from "multer";

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      res.status(413).json({ message: "File is too large" });
      return;
    }

    res.status(400).json({ message: error.message });
    return;
  }

  console.error(error);
  res.status(500).json({ message: "Upload failed" });
};