# Data validity rules

Business-rule checks run against the PostgreSQL database and shown in the
dashboard under **Summary and quality > Validity rules**.
Source: `eda/sql/validity_rules.sql`.

## How to read the results

| Column  |              Meaning            |
|---------|---------------------------------|
| failed  | Rows that break the rule        |
| checked | Rows evaluated.                 |
| pct     | `failed / checked * 100`        |
| status  | **OK**: 0%                      |
|         | **Warning**: under 1%           |
|         | **Check**: 1% or more           |

A status of Warning or Check does not always mean bad data. Rules 8 and 10
are flags for review, not defects.

## Rules

| #  | Table     | Rule                                             |
|----|-----------|--------------------------------------------------|
| 1  | games     | `owners_min <= owners_max`                       |
| 2  | games     | `total_reviews = positive + negative`            |
| 3  | games     | `approval_rate` between 0 and 100                |
| 4  | games     | `metacritic_score` between 0 and 100             |
| 5  | games     | `is_free` implies price is 0 or NULL             |
| 6  | games     | `ram_minimum_gb <= 128`                          | 
| 7  | games     | `ram_recommended_gb >= ram_minimum_gb`           |
| 8  | games     | `release_date <= today` (informational)          | 
| 9  | user_games| `playtime_2weeks <= playtime_forever`            |
| 10 | user_games| `playtime_forever <= 10,000 hours` (plausible)   |
| 11 | users     | `account_created <= now()`                       |

Maybe I'll add more rules in the future but I dont know if I'll remember to document it

## Known limitations

- Rows without data (NULL) are excluded from each rule, so a rule with a small
  `checked` count is based on a limited sample.
- Thresholds (128 GB RAM, 10,000 hours, 1% warning limit) are provisional and
  can be adjusted as the analysis progresses.
- The extraction regex for hardware requirements is the likely source of
  failures in rules 6 and 7.

## Adding or changing a rule

1. Add a `UNION ALL` block to `eda/sql/validity_rules.sql` returning
   `rule`, `failed` and `checked`.
2. Add a row to the table above.
3. Reload the app. No R code changes are needed.