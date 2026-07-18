-- init.sql - Steam Insights

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tabla: games
-- Catálogo de juegos (GetAppList + appdetails)
CREATE TABLE games (
    app_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    genre TEXT[],
    release_date DATE,
    price_usd NUMERIC(10,2),
    is_free BOOLEAN,
    developer TEXT,
    publisher TEXT,
    metacritic_score SMALLINT,
    positive_reviews INTEGER,
    negative_reviews INTEGER,
    fetched_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_games_name ON games USING gin (name gin_trgm_ops);
CREATE INDEX idx_games_genre ON games USING gin (genre);

-- Tabla: users
-- Perfiles de usuarios (GetPlayerSummaries)
CREATE TABLE users (
    steam_id BIGINT PRIMARY KEY,
    persona_name TEXT,
    profile_url TEXT,
    country_code CHAR(2),
    account_created TIMESTAMP,
    is_public BOOLEAN,
    fetched_at TIMESTAMP DEFAULT now()
);

-- Tabla: user_games
-- Relación usuario-juego (GetOwnedGames)
CREATE TABLE user_games (
    steam_id BIGINT REFERENCES users(steam_id) ON DELETE CASCADE,
    app_id INTEGER REFERENCES games(app_id) ON DELETE CASCADE,
    playtime_forever_minutes INTEGER,
    playtime_2weeks_minutes INTEGER,
    fetched_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (steam_id, app_id)
);

CREATE INDEX idx_user_games_app_id ON user_games (app_id);
CREATE INDEX idx_user_games_steam_id ON user_games (steam_id);

-- Tabla: achievements
-- Catálogo de logros por juego (GetSchemaForGame)
CREATE TABLE achievements (
    app_id INTEGER REFERENCES games(app_id) ON DELETE CASCADE,
    achievement_key TEXT,
    display_name TEXT,
    description TEXT,
    global_unlock_pct NUMERIC(5,2),
    PRIMARY KEY (app_id, achievement_key)
);

-- Tabla: user_achievements
-- Logros desbloqueados por usuario (GetPlayerAchievements)
CREATE TABLE user_achievements (
    steam_id BIGINT REFERENCES users(steam_id) ON DELETE CASCADE,
    app_id INTEGER,
    achievement_key TEXT,
    unlocked BOOLEAN,
    unlock_time TIMESTAMP,
    PRIMARY KEY (steam_id, app_id, achievement_key),
    FOREIGN KEY (app_id, achievement_key) REFERENCES achievements(app_id, achievement_key) ON DELETE CASCADE
);

CREATE INDEX idx_user_achievements_steam_id ON user_achievements (steam_id);

-- Tabla: raw_responses
-- Respaldo crudo de cada llamada a la API 
CREATE TABLE raw_responses (
    id SERIAL PRIMARY KEY,
    endpoint TEXT NOT NULL,
    request_params JSONB,
    response_body JSONB,
    fetched_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_raw_responses_endpoint ON raw_responses (endpoint);
CREATE INDEX idx_raw_responses_fetched_at ON raw_responses (fetched_at);