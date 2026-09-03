-- init.sql - Steam Insights

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tabla: games
CREATE TABLE games (
    app_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    short_description TEXT,
    genres TEXT[],
    categories TEXT[],
    supported_languages TEXT[],
    header_image TEXT,
    pc_requirements_minimum TEXT,
    pc_requirements_recommended TEXT,

    processor_minimum TEXT,
    processor_recommended TEXT,
    graphics_minimum TEXT,
    graphics_recommended TEXT,
    ram_minimum_gb SMALLINT,
    ram_recommended_gb SMALLINT,
    storage_minimum_gb SMALLINT,
    storage_recommended_gb SMALLINT,

    developers TEXT,
    is_on_windows BOOLEAN,
    is_on_mac BOOLEAN,
    is_on_linux BOOLEAN,
    metacritic_score SMALLINT,
    release_date DATE,
    price_usd NUMERIC(10,2),
    is_free BOOLEAN,
    rating TEXT,
    total_achievements SMALLINT,
    recommendations INTEGER,

    -- (SteamSpy metrics)
    owners_min BIGINT,
    owners_max BIGINT,
    positive_reviews INTEGER,
    negative_reviews INTEGER,
    total_reviews INTEGER,
    approval_rate NUMERIC(5,2),
    fetched_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_games_name ON games USING gin (name gin_trgm_ops);
CREATE INDEX idx_games_genres ON games USING gin (genres);
-- Tabla: users
-- Perfiles de usuarios (GetPlayerSummaries)
CREATE TABLE users (
    steam_id BIGINT PRIMARY KEY,
    persona_name TEXT,
    profile_url TEXT,
    avatar_url TEXT,
    country_code CHAR(2),
    account_created TIMESTAMP,
    is_public BOOLEAN,
    has_public_games BOOLEAN DEFAULT false, --false until proven otherwise
    has_public_achievements BOOLEAN DEFAULT false,
    games_fetched BOOLEAN DEFAULT NULL;
    fetched_at TIMESTAMP DEFAULT now()
);

-- Tabla: user_games
CREATE TABLE user_games (
    steam_id BIGINT REFERENCES users(steam_id) ON DELETE CASCADE,
    app_id INTEGER REFERENCES games(app_id) ON DELETE CASCADE,
    playtime_forever INTEGER,
    playtime_2weeks INTEGER,
    achievements_status TEXT DEFAULT 'pending', --'success', 'private', 'no achievements'
    PRIMARY KEY (steam_id, app_id)
);

CREATE INDEX idx_user_games_app_id ON user_games (app_id);
CREATE INDEX idx_user_games_steam_id ON user_games (steam_id);

-- Tabla: achievements
CREATE TABLE achievements (
    app_id INTEGER REFERENCES games(app_id) ON DELETE CASCADE,
    achievement_key TEXT,
    display_name TEXT,
    achievement_desc TEXT,
    global_unlock_pct NUMERIC(5,2),
    PRIMARY KEY (app_id, achievement_key)
);

CREATE INDEX idx_achievement_key ON achievements (achievement_key);

-- Tabla: user_achievements
CREATE TABLE user_achievements (
    steam_id BIGINT REFERENCES users(steam_id) ON DELETE CASCADE,
    app_id INTEGER,
    achievement_key TEXT,
    unlocktime DATE,
    PRIMARY KEY (steam_id, app_id, achievement_key),
    FOREIGN KEY (app_id, achievement_key) REFERENCES achievements(app_id, achievement_key) ON DELETE CASCADE
);

CREATE INDEX idx_user_achievements_steam_id ON user_achievements (steam_id);
CREATE INDEX idx_user_achievements_app ON user_achievements (app_id);

-- Tabla: raw_responses
CREATE TABLE raw_responses (
    id SERIAL PRIMARY KEY,
    endpoint TEXT NOT NULL,
    request_params JSONB,
    response_body JSONB,
    fetched_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_raw_responses_endpoint ON raw_responses (endpoint);
CREATE INDEX idx_raw_responses_fetched_at ON raw_responses (fetched_at);