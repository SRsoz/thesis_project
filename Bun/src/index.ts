import path from "node:path";
import express from "express";
import cors from "cors";
import uploadsRouter from "./routes/uploads";
import { errorHandler } from "./middleware/errorHandler";

const app = express();

app.use(cors());
app.use(express.json());

app.use("/uploads", express.static(path.resolve(process.cwd(), "uploads")));

app.get("/", (_req, res) => {
  res.send("Backend is working");
});

app.use("/api/uploads", uploadsRouter);

app.use(errorHandler);

const PORT = 3000;

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});