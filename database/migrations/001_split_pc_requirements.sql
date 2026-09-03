-- Add new columns
ALTER TABLE games
  ADD COLUMN processor_minimum TEXT,
  ADD COLUMN processor_recommended TEXT,
  ADD COLUMN graphics_minimum TEXT,
  ADD COLUMN graphics_recommended TEXT,
  ADD COLUMN ram_minimum_gb SMALLINT,
  ADD COLUMN ram_recommended_gb SMALLINT,
  ADD COLUMN storage_minimum_gb SMALLINT,
  ADD COLUMN storage_recommended_gb SMALLINT;

-- Migrate data
UPDATE games SET
  processor_minimum = processor[1],
  processor_recommended = processor[2],
  graphics_minimum = graphics[1],
  graphics_recommended = graphics[2],
  ram_minimum_gb  = ram_requirement[1],
  ram_recommended_gb = ram_requirement[2],
  storage_minimum_gb = storage_requirement[1],
  storage_recommended_gb = storage_requirement[2];

-- delete old columns
ALTER TABLE games
  DROP COLUMN processor,
  DROP COLUMN graphics,
  DROP COLUMN ram_requirement,
  DROP COLUMN storage_requirement;

-- I fucked up
-- dont know if this is going to have consequences in the future but I want to documentate what i did
-- script to migrate data:
-- Get-Content database/migrations/<migration_file>.sql | docker exec -i <postgres_container_name> psql -U <db_user> -d <db_name>