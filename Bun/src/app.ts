import express from "express";
import cors from "cors";
import uploadsRouter, { uploadsDir } from "./routes/uploads";
import { errorHandler } from "./middleware/errorHandler";

const app = express();

app.use(cors());
app.use(express.json());

app.use("/uploads", express.static(uploadsDir));

app.get("/", (_req, res) => {
  res.send("Backend is working");
});

app.use("/api/uploads", uploadsRouter);

app.use(errorHandler);

export default app;
