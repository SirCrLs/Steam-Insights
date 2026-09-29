ALTER TABLE users
  ADD COLUMN IF NOT EXISTS achievements_fetched BOOLEAN NOT NULL DEFAULT TRUE;

-- New users start with false
ALTER TABLE users
  ALTER COLUMN achievements_fetched SET DEFAULT FALSE;