import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  test,
} from "bun:test";
import { Buffer } from "node:buffer";
import { mkdir, readdir, rm } from "node:fs/promises";
import path from "node:path";
import type { Server } from "node:http";
import { Client } from "pg";

const testDatabaseUrl =
  process.env.TEST_DATABASE_URL ??
  "postgresql://postgres:postgres@localhost:5432/thesis_bun_test";
const testUploadsDir = path.resolve(process.cwd(), ".test-uploads");

let baseUrl: string;
let server: Server;
let prisma: Awaited<typeof import("../src/lib/prisma")>["prisma"];

beforeAll(async () => {
  assertTestDatabaseUrl(testDatabaseUrl);

  process.env.DATABASE_URL = testDatabaseUrl;
  process.env.UPLOADS_DIR = testUploadsDir;

  await ensureTestDatabase(testDatabaseUrl);
  await resetTestSchema(testDatabaseUrl);
  await runPrismaMigrations(testDatabaseUrl);

  const appModule = await import("../src/app");
  const prismaModule = await import("../src/lib/prisma");
  prisma = prismaModule.prisma;

  server = appModule.default.listen(0);
  await new Promise<void>((resolve) => server.once("listening", resolve));

  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Could not start test server");
  }

  baseUrl = `http://127.0.0.1:${address.port}`;
});

beforeEach(async () => {
  await cleanTestState();
});

afterEach(async () => {
  await cleanTestState();
});

afterAll(async () => {
  await prisma?.$disconnect();
  await new Promise<void>((resolve, reject) => {
    if (!server) {
      resolve();
      return;
    }

    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }

      resolve();
    });
  });
  await rm(testUploadsDir, { recursive: true, force: true });
});

describe("POST /api/uploads", () => {
  test("stores a valid png file on disk and in the database", async () => {
    const response = await uploadFile("pixel.png", "image/png", pngBytes());
    const body = await response.json();

    expect(response.status).toBe(201);
    expect(body.message).toBe("Upload successful");
    expect(body.file.originalName).toBe("pixel.png");
    expect(body.file.mimeType).toBe("image/png");
    expect(body.file.fileName).toEndWith(".png");
    expect(body.file.url).toBe(`/uploads/${body.file.fileName}`);

    const uploads = await prisma.bunUpload.findMany();
    expect(uploads).toHaveLength(1);
    expect(uploads[0].originalName).toBe("pixel.png");
    expect(uploads[0].fileName).toBe(body.file.fileName);

    expect(await uploadedFileNames()).toContain(body.file.fileName);
  });

  test("stores a valid jpeg file on disk and in the database", async () => {
    const response = await uploadFile("photo.jpg", "image/jpeg", jpegBytes());
    const body = await response.json();

    expect(response.status).toBe(201);
    expect(body.file.mimeType).toBe("image/jpeg");
    expect(body.file.fileName).toEndWith(".jpg");

    const uploads = await prisma.bunUpload.findMany();
    expect(uploads).toHaveLength(1);
    expect(uploads[0].originalName).toBe("photo.jpg");
  });

  test("rejects requests without a file", async () => {
    const response = await fetch(`${baseUrl}/api/uploads`, {
      method: "POST",
      body: new FormData(),
    });
    const body = await response.json();

    expect(response.status).toBe(400);
    expect(body.message).toBe("No file was uploaded");
    expect(await prisma.bunUpload.count()).toBe(0);
    expect(await uploadedFileNames()).toEqual([]);
  });

  test("rejects files whose content is not png or jpeg", async () => {
    const response = await uploadFile("notes.txt", "text/plain", Buffer.from("hello"));
    const body = await response.json();

    expect(response.status).toBe(415);
    expect(body.message).toBe("Only png and jpeg files allowed");
    expect(await prisma.bunUpload.count()).toBe(0);
    expect(await uploadedFileNames()).toEqual([]);
  });

  test("rejects files larger than 20MB", async () => {
    const response = await uploadFile("large.png", "image/png", oversizedPngBytes());
    const body = await response.json();

    expect(response.status).toBe(413);
    expect(body.message).toBe("File is too large");
    expect(await prisma.bunUpload.count()).toBe(0);
    expect(await uploadedFileNames()).toEqual([]);
  });
});

async function uploadFile(fileName: string, mimeType: string, bytes: Buffer) {
  const formData = new FormData();
  const fileBytes = new Uint8Array(bytes.length);
  fileBytes.set(bytes);
  formData.append("file", new File([fileBytes], fileName, { type: mimeType }));

  return fetch(`${baseUrl}/api/uploads`, {
    method: "POST",
    body: formData,
  });
}

async function emptyUploadsDir() {
  await rm(testUploadsDir, { recursive: true, force: true });
  await mkdir(testUploadsDir, { recursive: true });
}

async function cleanTestState() {
  await prisma.bunUpload.deleteMany();
  await emptyUploadsDir();
}

async function uploadedFileNames() {
  const files = await readdir(testUploadsDir);
  return files.filter((file) => file.endsWith(".png") || file.endsWith(".jpg"));
}

async function ensureTestDatabase(databaseUrl: string) {
  const url = new URL(databaseUrl);
  const databaseName = url.pathname.slice(1);

  const adminUrl = new URL(databaseUrl);
  adminUrl.pathname = "/postgres";

  const client = new Client({ connectionString: adminUrl.toString() });
  await client.connect();

  const exists = await client.query("SELECT 1 FROM pg_database WHERE datname = $1", [
    databaseName,
  ]);

  if (exists.rowCount === 0) {
    await client.query(`CREATE DATABASE ${quoteIdentifier(databaseName)}`);
  }

  await client.end();
}

async function resetTestSchema(databaseUrl: string) {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  await client.query('DROP SCHEMA IF EXISTS "public" CASCADE');
  await client.query('CREATE SCHEMA "public"');
  await client.end();
}

async function runPrismaMigrations(databaseUrl: string) {
  const migrationProcess = Bun.spawn({
    cmd: [process.execPath, "x", "prisma", "migrate", "deploy"],
    cwd: process.cwd(),
    env: {
      ...process.env,
      DATABASE_URL: databaseUrl,
    },
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(migrationProcess.stdout).text(),
    new Response(migrationProcess.stderr).text(),
    migrationProcess.exited,
  ]);

  if (exitCode !== 0) {
    throw new Error(
      `Prisma migrations failed with exit code ${exitCode}\n${stdout}\n${stderr}`,
    );
  }
}

function assertTestDatabaseUrl(databaseUrl: string) {
  const databaseName = new URL(databaseUrl).pathname.slice(1);

  if (!databaseName.toLowerCase().includes("test")) {
    throw new Error(
      `Refusing to run integration tests against non-test database "${databaseName}"`,
    );
  }
}

function quoteIdentifier(identifier: string) {
  if (!/^[A-Za-z0-9_-]+$/.test(identifier)) {
    throw new Error(`Unsafe database name "${identifier}"`);
  }

  return `"${identifier.replaceAll('"', '""')}"`;
}

function pngBytes() {
  return Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
    "base64",
  );
}

function oversizedPngBytes() {
  const header = pngBytes();
  const maxFileSize = 20 * 1024 * 1024;
  return Buffer.concat([header, Buffer.alloc(maxFileSize + 1 - header.length, 1)]);
}

function jpegBytes() {
  return Buffer.from(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAH/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAEFAqf/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/ASP/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/ASP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAY/Al//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/IV//2gAMAwEAAgADAAAAEP/EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQMBAT8QH//EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQIBAT8QH//EABQQAQAAAAAAAAAAAAAAAAAAABD/2gAIAQEAAT8QH//Z",
    "base64",
  );
}
