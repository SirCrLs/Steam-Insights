-- =============================================================================
--   layer 1 (aux)
--     v_ach_by_user_game          achievements unlocked by (user, game)
--     mv_game_ach_stats           achievements defined by game
--     mv_game_genres              table between game-genre
--   layer 2 (levels)
--     mv_level_game               1 row = 1 game
--     mv_level_user               1 row = 1 user
--     mv_level_usergame_sample    1 row = 1 row of user_games
--     mv_level_achievement_sample 1 row = 1 achievement
--   Support
--     eda_refresh_log             logs of refreshing
--     eda_refresh_levels()        refresh everything
-- =============================================================================

BEGIN;

-- Cleaning
DROP MATERIALIZED VIEW IF EXISTS mv_level_achievement_sample CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_level_usergame_sample    CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_level_user               CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_level_game               CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_game_genres              CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_game_ach_stats           CASCADE;
DROP VIEW              IF EXISTS v_ach_by_user_game          CASCADE;

CREATE TABLE IF NOT EXISTS eda_refresh_log (
    view_name    TEXT PRIMARY KEY,
    refreshed_at TIMESTAMP NOT NULL DEFAULT now(),
    row_count    BIGINT
);

-- LAYER 1 Aux

-- achievements unlocked by user and game
CREATE VIEW v_ach_by_user_game AS
SELECT steam_id, app_id, COUNT(*)::int AS n_unlocked
FROM user_achievements
GROUP BY steam_id, app_id;

-- Achievements defined by game
CREATE MATERIALIZED VIEW mv_game_ach_stats AS
SELECT app_id,
       COUNT(*)::int                                         AS n_achievements_defined,
       AVG(global_unlock_pct)::float8                        AS avg_global_unlock_pct,
       MIN(global_unlock_pct)::float8                        AS min_global_unlock_pct,
       (100.0 * AVG((global_unlock_pct < 5)::int))::float8   AS pct_rare_achievements
FROM achievements
GROUP BY app_id
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_game_ach_stats ON mv_game_ach_stats (app_id);

-- table between game-genre
CREATE MATERIALIZED VIEW mv_game_genres AS
SELECT DISTINCT g.app_id, gn AS genre
FROM games g
CROSS JOIN LATERAL unnest(g.genres) AS gn
WHERE gn IS NOT NULL
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_game_genres ON mv_game_genres (app_id, genre);
CREATE INDEX        ix_mv_game_genres_genre ON mv_game_genres (genre);

-- LAYER 2 levels

-- GAMES
CREATE MATERIALIZED VIEW mv_level_game AS
WITH ug AS (
    SELECT app_id,
           COUNT(*)::int                                                         AS n_users,
           AVG(playtime_forever)::float8                                         AS avg_playtime_forever,
           (percentile_cont(0.5) WITHIN GROUP (ORDER BY playtime_forever))::float8 AS median_playtime_forever,
           (100.0 * AVG((playtime_forever > 0)::int))::float8                    AS pct_users_played,
           AVG(playtime_2weeks)::float8                                          AS avg_playtime_2weeks
    FROM user_games
    GROUP BY app_id
),
uach AS (   -- Only users with achievements scrapped
    SELECT ug.app_id,
           COUNT(*)::int AS n_users_ach_data,
           AVG(100.0 * COALESCE(a.n_unlocked, 0) / s.n_achievements_defined)::float8 AS avg_pct_completed
    FROM user_games ug
    JOIN mv_game_ach_stats s
      ON s.app_id = ug.app_id AND s.n_achievements_defined > 0
    LEFT JOIN v_ach_by_user_game a
      ON a.steam_id = ug.steam_id AND a.app_id = ug.app_id
    WHERE ug.achievements_status = 'success'
    GROUP BY ug.app_id
)
SELECT g.app_id, g.name,
       g.price_usd, g.is_free, g.metacritic_score,
       g.release_date, EXTRACT(YEAR FROM g.release_date)::int AS release_year,
       g.total_achievements, g.recommendations,
       g.owners_min, g.owners_max,
       g.positive_reviews, g.negative_reviews, g.total_reviews, g.approval_rate,
       g.ram_minimum_gb, g.ram_recommended_gb,
       g.storage_minimum_gb, g.storage_recommended_gb,
       g.is_on_windows, g.is_on_mac, g.is_on_linux, g.rating,
       g.genres[1]                          AS primary_genre,
       COALESCE(cardinality(g.genres), 0)              AS n_genres,
       COALESCE(cardinality(g.categories), 0)          AS n_categories,
       COALESCE(cardinality(g.supported_languages), 0) AS n_languages,
       -- achievements
       s.n_achievements_defined, s.avg_global_unlock_pct,
       s.min_global_unlock_pct, s.pct_rare_achievements,
       -- user metrics
       ug.n_users, ug.avg_playtime_forever, ug.median_playtime_forever,
       ug.pct_users_played, ug.avg_playtime_2weeks,
       -- achievements by user
       uach.n_users_ach_data, uach.avg_pct_completed
FROM games g
LEFT JOIN mv_game_ach_stats s ON s.app_id = g.app_id
LEFT JOIN ug                  ON ug.app_id = g.app_id
LEFT JOIN uach                ON uach.app_id = g.app_id
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_level_game ON mv_level_game (app_id);

-- USER 
CREATE MATERIALIZED VIEW mv_level_user AS
WITH ug AS (
    SELECT steam_id,
           COUNT(*)::int                                       AS games_owned,
           SUM(playtime_forever)::float8                       AS total_playtime,
           AVG(playtime_forever)::float8                       AS avg_playtime,
           (100.0 * AVG((playtime_forever > 0)::int))::float8  AS pct_games_played,
           SUM(COALESCE(playtime_2weeks, 0))::float8           AS total_playtime_2weeks,
           (COUNT(*) FILTER (WHERE achievements_status = 'success'))::int AS n_games_ach_data
    FROM user_games
    GROUP BY steam_id
),
uach AS (
    SELECT ug.steam_id,
           SUM(COALESCE(a.n_unlocked, 0))::int AS achievements_unlocked,
           AVG(100.0 * COALESCE(a.n_unlocked, 0) / s.n_achievements_defined)::float8 AS avg_pct_completed
    FROM user_games ug
    JOIN mv_game_ach_stats s
      ON s.app_id = ug.app_id AND s.n_achievements_defined > 0
    LEFT JOIN v_ach_by_user_game a
      ON a.steam_id = ug.steam_id AND a.app_id = ug.app_id
    WHERE ug.achievements_status = 'success'
    GROUP BY ug.steam_id
)
SELECT u.steam_id, u.persona_name, u.country_code,
       u.is_public, u.has_public_games, u.has_public_achievements,
       u.account_created,
       EXTRACT(YEAR FROM u.account_created)::int                          AS account_year,
       (EXTRACT(EPOCH FROM (now() - u.account_created)) / 86400.0)::float8 AS account_age_days,
       ug.games_owned, ug.total_playtime, ug.avg_playtime,
       ug.pct_games_played, ug.total_playtime_2weeks,
       (COALESCE(ug.n_games_ach_data, 0) > 0)                             AS has_ach_data,
       CASE WHEN COALESCE(ug.n_games_ach_data, 0) > 0
            THEN COALESCE(uach.achievements_unlocked, 0) END              AS achievements_unlocked,
       uach.avg_pct_completed
FROM users u
LEFT JOIN ug   ON ug.steam_id   = u.steam_id
LEFT JOIN uach ON uach.steam_id = u.steam_id
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_level_user ON mv_level_user (steam_id);

-- USER × GAME
CREATE MATERIALIZED VIEW mv_level_usergame_sample AS
WITH base AS (
    SELECT steam_id, app_id, playtime_forever, playtime_2weeks,
           achievements_status, random() AS rnd
    FROM user_games
),
picked AS (
    SELECT * FROM base
    WHERE rnd < 1 OR achievements_status = 'success'
)
SELECT p.steam_id, p.app_id,
       p.playtime_forever, p.playtime_2weeks,
       (p.rnd < 1)                          AS in_uniform,
       (p.achievements_status = 'success')     AS has_ach_data,
       CASE WHEN p.achievements_status = 'success'
            THEN COALESCE(a.n_unlocked, 0) END AS achievements_unlocked,
       CASE WHEN p.achievements_status = 'success' AND s.n_achievements_defined > 0
            THEN (100.0 * COALESCE(a.n_unlocked, 0) / s.n_achievements_defined)::float8 END AS pct_completed,
       g.price_usd, g.is_free, g.approval_rate, g.total_reviews, g.positive_reviews,
       g.metacritic_score, g.total_achievements,
       EXTRACT(YEAR FROM g.release_date)::int  AS release_year,
       g.genres[1]                             AS primary_genre,
       u.country_code,
       EXTRACT(YEAR FROM u.account_created)::int AS account_year
FROM picked p
JOIN games g                    ON g.app_id = p.app_id
LEFT JOIN users u               ON u.steam_id = p.steam_id
LEFT JOIN mv_game_ach_stats s   ON s.app_id = p.app_id
LEFT JOIN v_ach_by_user_game a  ON a.steam_id = p.steam_id AND a.app_id = p.app_id
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_level_usergame_sample ON mv_level_usergame_sample (steam_id, app_id);
CREATE INDEX        ix_mv_level_usergame_sample_uniform ON mv_level_usergame_sample (in_uniform);
CREATE INDEX        ix_mv_level_usergame_sample_app ON mv_level_usergame_sample (app_id);

-- ACHIEVEMENT
CREATE MATERIALIZED VIEW mv_level_achievement_sample AS
WITH base AS (
    SELECT app_id, achievement_key, display_name, achievement_desc,
           global_unlock_pct, random() AS rnd
    FROM achievements
),
picked AS (
    SELECT * FROM base WHERE rnd < 1
)
SELECT p.app_id, p.achievement_key, p.display_name,
       p.global_unlock_pct,
       LENGTH(p.display_name)     AS name_length,
       LENGTH(p.achievement_desc) AS desc_length,
       CASE WHEN p.global_unlock_pct IS NULL THEN NULL
            WHEN p.global_unlock_pct <  1  THEN 'Ultra rara (<1%)'
            WHEN p.global_unlock_pct <  5  THEN 'Rara (1-5%)'
            WHEN p.global_unlock_pct < 20  THEN 'Poco común (5-20%)'
            WHEN p.global_unlock_pct < 50  THEN 'Común (20-50%)'
            ELSE 'Muy común (≥50%)' END AS rarity_tier,
       g.name AS game_name,
       g.price_usd, g.is_free, g.approval_rate, g.total_reviews, g.positive_reviews,
       g.metacritic_score,
       EXTRACT(YEAR FROM g.release_date)::int AS release_year,
       g.genres[1]                            AS primary_genre,
       s.n_achievements_defined
FROM picked p
JOIN games g                   ON g.app_id = p.app_id
LEFT JOIN mv_game_ach_stats s  ON s.app_id = p.app_id
WITH NO DATA;
CREATE UNIQUE INDEX ux_mv_level_achievement_sample
    ON mv_level_achievement_sample (app_id, achievement_key);
CREATE INDEX ix_mv_level_achievement_sample_app
    ON mv_level_achievement_sample (app_id);

-- refresh
CREATE OR REPLACE FUNCTION eda_refresh_levels() RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v TEXT;
    n BIGINT;
BEGIN
    FOREACH v IN ARRAY ARRAY[
        'mv_game_ach_stats',
        'mv_game_genres',
        'mv_level_game',
        'mv_level_user',
        'mv_level_usergame_sample',
        'mv_level_achievement_sample'
    ] LOOP
        EXECUTE format('REFRESH MATERIALIZED VIEW %I', v);
        EXECUTE format('SELECT COUNT(*) FROM %I', v) INTO n;
        INSERT INTO eda_refresh_log (view_name, refreshed_at, row_count)
        VALUES (v, now(), n)
        ON CONFLICT (view_name)
        DO UPDATE SET refreshed_at = EXCLUDED.refreshed_at,
                      row_count    = EXCLUDED.row_count;
    END LOOP;
END;
$$;

COMMIT;

SELECT eda_refresh_levels();

-- fast verify
SELECT * FROM eda_refresh_log ORDER BY view_name;

SELECT 'usergame_sample' AS vista,
       COUNT(*)                                  AS filas,
       COUNT(*) FILTER (WHERE in_uniform)        AS filas_muestra_uniforme,
       COUNT(*) FILTER (WHERE has_ach_data)      AS filas_con_logros
FROM mv_level_usergame_sample;

SELECT 'user' AS vista,
       COUNT(*)                                  AS filas,
       COUNT(*) FILTER (WHERE has_ach_data)      AS usuarios_con_logros
FROM mv_level_user;
