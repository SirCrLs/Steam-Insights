-- ============================================================
-- Data validity rules (Summary & quality > "Validity rules" tab)
--
-- Each block checks one business rule and returns a single row:
--   rule     human-readable description of the check
--   failed   number of rows that break the rule
--   checked  number of rows evaluated (NULLs are excluded, since
--            a missing value cannot be validated)
--
-- The app computes pct = failed / checked and assigns a status:
--   OK = 0%   Warning = under 1%   Check = 1% or more
--
-- Rules marked (informational) or (plausibility) are not
-- necessarily errors. They flag rows worth reviewing.
-- To add a rule, append another UNION ALL block with the same
-- three columns.
-- ============================================================

-- 1. SteamSpy owner ranges must be ordered (min <= max)
SELECT 'games: owners_min > owners_max' AS rule,
       count(*) FILTER (WHERE owners_min > owners_max) AS failed,
       count(*) AS checked
FROM games
WHERE owners_min IS NOT NULL AND owners_max IS NOT NULL

UNION ALL

-- 2. Review totals must add up
SELECT 'games: total_reviews <> positive + negative',
       count(*) FILTER (WHERE total_reviews <> positive_reviews + negative_reviews),
       count(*)
FROM games
WHERE total_reviews IS NOT NULL

UNION ALL

-- 3. Approval rate is a percentage
SELECT 'games: approval_rate outside 0-100',
       count(*) FILTER (WHERE approval_rate NOT BETWEEN 0 AND 100),
       count(*)
FROM games
WHERE approval_rate IS NOT NULL

UNION ALL

-- 4. Metacritic scores range from 0 to 100
SELECT 'games: metacritic_score outside 0-100',
       count(*) FILTER (WHERE metacritic_score NOT BETWEEN 0 AND 100),
       count(*)
FROM games
WHERE metacritic_score IS NOT NULL

UNION ALL

-- 5. A free game cannot have a price
SELECT 'games: is_free with price > 0',
       count(*) FILTER (WHERE is_free AND price_usd > 0),
       count(*)
FROM games
WHERE is_free IS NOT NULL

UNION ALL

-- 6. Minimum RAM above 128 GB points to a parsing error (MB or MHz read as GB)
SELECT 'games: minimum RAM > 128 GB (extraction error)',
       count(*) FILTER (WHERE ram_minimum_gb > 128),
       count(*)
FROM games
WHERE ram_minimum_gb IS NOT NULL

UNION ALL

-- 7. Recommended RAM should not be lower than the minimum
SELECT 'games: recommended RAM < minimum RAM',
       count(*) FILTER (WHERE ram_recommended_gb < ram_minimum_gb),
       count(*)
FROM games
WHERE ram_recommended_gb IS NOT NULL AND ram_minimum_gb IS NOT NULL

UNION ALL

-- 8. Upcoming releases, expected rather than erroneous
SELECT 'games: release date in the future (informational)',
       count(*) FILTER (WHERE release_date > CURRENT_DATE),
       count(*)
FROM games
WHERE release_date IS NOT NULL

UNION ALL

-- 9. Playtime in the last 2 weeks cannot exceed total playtime
SELECT 'user_games: 2-week playtime > total playtime',
       count(*) FILTER (WHERE playtime_2weeks > playtime_forever),
       count(*)
FROM user_games

UNION ALL

-- 10. More than 10,000 hours in one game (playtime is stored in minutes)
SELECT 'user_games: more than 10,000 hours in one game (plausibility)',
       count(*) FILTER (WHERE playtime_forever > 600000),
       count(*)
FROM user_games

UNION ALL

-- 11. An account cannot be created in the future
SELECT 'users: account created in the future',
       count(*) FILTER (WHERE account_created > now()),
       count(*)
FROM users
WHERE account_created IS NOT NULL

UNION ALL

-- 12. global pct should be between 0 and 100
SELECT 'achievements: global_unlock_pct outside 0-100',
       count(*) FILTER (WHERE global_unlock_pct NOT BETWEEN 0 AND 100),
       count(*)
FROM achievements
WHERE global_unlock_pct IS NOT NULL

UNION ALL

-- 13. unlock time cannot be on the future
SELECT 'user_achievements: unlocktime in the future',
       count(*) FILTER (WHERE unlock_time > CURRENT_DATE),
       count(*)
FROM user_achievements
WHERE unlock_time IS NOT NULL

UNION ALL

-- 14. recommended storage < minimum storage
SELECT 'games: recommended storage < minimum storage',
       count(*) FILTER (WHERE storage_recommended_gb < storage_minimum_gb),
       count(*)
FROM games
WHERE storage_recommended_gb IS NOT NULL AND storage_minimum_gb IS NOT NULL

UNION ALL

-- 15. storage is more than 500 gb. Probably an extraction error
SELECT 'games: minimum storage > 500 GB (extraction error)',
       count(*) FILTER (WHERE storage_minimum_gb > 500),
       count(*)
FROM games
WHERE storage_minimum_gb IS NOT NULL

UNION ALL

-- 16. total achievements cannot go negative
SELECT 'games: negative total_achievements',
       count(*) FILTER (WHERE total_achievements < 0),
       count(*)
FROM games
WHERE total_achievements IS NOT NULL

UNION ALL

-- 17. recommendations cannot go negative
SELECT 'games: negative recommendations',
       count(*) FILTER (WHERE recommendations < 0),
       count(*)
FROM games
WHERE recommendations IS NOT NULL

UNION ALL

-- 18. country code should only be 2 characters (ISO format)
SELECT 'users: country_code format invalid',
       count(*) FILTER (WHERE country_code !~ '^[A-Z]{2}$'),
       count(*)
FROM users
WHERE country_code IS NOT NULL

UNION ALL

-- 19. playtime cannot be negative
SELECT 'user_games: negative playtime_forever',
       count(*) FILTER (WHERE playtime_forever < 0),
       count(*)
FROM user_games
WHERE playtime_forever IS NOT NULL

UNION ALL

-- 20. same as 19 but for playtime on 2 weeks
SELECT 'user_games: negative playtime_2weeks',
       count(*) FILTER (WHERE playtime_2weeks < 0),
       count(*)
FROM user_games
WHERE playtime_2weeks IS NOT NULL;