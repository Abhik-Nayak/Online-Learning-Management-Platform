// LearnHub LMS - tiny Express server.
// Serves the static site from ./public and two JSON endpoints:
//   GET /api/health     -> app is up (no DB needed)
//   GET /api/db-health  -> runs a query against PostgreSQL
// DB settings come ONLY from environment variables (set by Ansible / docker run).

const express = require("express");
const path = require("path");
const os = require("os");
const { Pool } = require("pg");

const PORT = parseInt(process.env.PORT || "3000", 10);
const HOSTNAME = os.hostname();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || "5432", 10),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 5,
  connectionTimeoutMillis: 3000, // fail fast if the DB is unreachable
});

// An idle client erroring (e.g. DB restarted) must not crash the app.
pool.on("error", (err) => console.error("pg pool error:", err.message));

const app = express();

app.use(express.static(path.join(__dirname, "public")));

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", host: HOSTNAME });
});

app.get("/api/db-health", async (req, res) => {
  if (!process.env.DB_HOST) {
    return res.status(500).json({ db: "error", message: "DB_HOST is not set", served_by: HOSTNAME });
  }
  try {
    const { rows } = await pool.query("SELECT now() AS time, version() AS version");
    res.json({
      db: "connected",
      time: rows[0].time,
      version: rows[0].version,
      served_by: HOSTNAME,
    });
  } catch (err) {
    res.status(500).json({ db: "error", message: err.message, served_by: HOSTNAME });
  }
});

const server = app.listen(PORT, () => {
  console.log(`LMS app listening on port ${PORT} (host ${HOSTNAME})`);
});

// Clean shutdown when Docker stops the container.
process.on("SIGTERM", () => {
  server.close(() => pool.end().finally(() => process.exit(0)));
});
