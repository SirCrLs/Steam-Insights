CREATE OR REPLACE VIEW v_games_clean AS
SELECT
  app_id, name, genres, release_date,
  EXTRACT(YEAR FROM release_date)::int AS release_year,
  price_usd, is_free, metacritic_score, total_achievements,
  owners_min, owners_max, (owners_min + owners_max) / 2.0 AS owners_mid,
  positive_reviews, negative_reviews, total_reviews, approval_rate,
  -- Wilson lower bound score
  CASE WHEN total_reviews > 0 THEN
    ( (positive_reviews::float / total_reviews) + 1.9208 / total_reviews
      - 1.96 * sqrt( ((positive_reviews::float / total_reviews)
                      * (1 - positive_reviews::float / total_reviews)
                      + 0.9604 / total_reviews) / total_reviews ) )
    / (1 + 3.8416 / total_reviews)
  END AS wilson_score,
  -- Out of range
  CASE WHEN ram_minimum_gb         BETWEEN 1 AND 128 THEN ram_minimum_gb         END AS ram_minimum_gb,
  CASE WHEN ram_recommended_gb     BETWEEN 1 AND 128 THEN ram_recommended_gb     END AS ram_recommended_gb,
  CASE WHEN storage_minimum_gb     BETWEEN 1 AND 500 THEN storage_minimum_gb     END AS storage_minimum_gb,
  CASE WHEN storage_recommended_gb BETWEEN 1 AND 500 THEN storage_recommended_gb END AS storage_recommended_gb,
  is_on_windows, is_on_mac, is_on_linux,
  (owners_min IS NOT NULL) AS has_steamspy
FROM games
WHERE short_description IS NOT NULL
  AND release_date BETWEEN DATE '1990-01-01' AND CURRENT_DATE;

CREATE OR REPLACE VIEW v_user_summary AS
SELECT
  u.steam_id, u.country_code, u.account_created,
  u.is_public, u.has_public_games, u.has_public_achievements, u.achievements_fetched,
  count(ug.app_id)                                        AS games_owned,
  count(*) FILTER (WHERE ug.playtime_forever > 0)         AS games_played,
  coalesce(sum(ug.playtime_forever), 0) / 60.0            AS hours_total
FROM users u
LEFT JOIN user_games ug ON ug.steam_id = u.steam_id
GROUP BY u.steam_id;