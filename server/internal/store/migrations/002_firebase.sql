ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR;

CREATE UNIQUE INDEX IF NOT EXISTS users_firebase_uid ON users (firebase_uid);
