# Steam Insights - ETL Microservice

This document outlines the core components of the ETL (Extract, Transform, Load) microservice responsible for fetching data from the Steam API and SteamSpy, processing it, and storing it into our PostgreSQL database.

## `Requirements`

* **.env file:** In order to ETL to work properly it needs an .env file with
  * **Database data:** it need to have `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DB_NAME`, `DB_HOST`, `DB_PORT` and `DATABASE_URL` in order to connect to a postgres database.
  * **Steam api key:** Get your steam api key here: [https://steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey) and put it on the .env with the name `STEAM_API_KEY`
  * There is a [.env-example](../.env-example) on project root

* **Seed IDs file:** It cant get users out of nowhere so you need to create a text file called `seed_steam_ids.txt` and add at least 1 steam ID to not break the process. There is an [example](../data/seed_steam_ids-example.txt) on data folder

## Start the container (Docker)

The ETL service is fully containerized using a lightweight Python 3.12 environment. It is managed by the root `docker-compose.yml` file, which ensures it only starts after the PostgreSQL database is fully initialized and healthy.

### Prerequisites
Ensure you have a `.env` file in the root of your project containing the necessary environment variables (e.g., `STEAM_API_KEY`, database credentials).

### Execution Commands

Run these commands from the **root directory** of the project, not inside the `etl/` folder.

**To run the ETL service and its database dependency:**
```bash
docker compose run --rm etl
```
This will run the code on the terminal
*(Note: If you made changes to the code, force a rebuild by running `docker-compose build etl`)*

### Volumes & Architecture
* The local `../data` folder is mounted to `/app/data` inside the container. This ensures that downloaded SteamSpy JSON pages and the `seed_steam_ids.txt` file persist between container restarts.
* The container will wait for the `postgres` healthcheck to pass before executing `main.py`.

## `main.py` (Main Orchestrator)

* **Purpose:** Acts as the entry point for the ETL microservice, orchestrating the sequential execution of user extraction, game extraction, and database view updates.

* **Configuration and Global Variables:**

  * Loads credentials using the `dotenv` library, specifically extracting the `STEAM_API_KEY` environment variable.

  * Sets extraction limits by defining `MAX_PAGE = N` (to iterate over the SteamSpy catalog) and `MAX_USERS = M`. Those variables can be changed if you want to

  * Defines in-memory batch load sizes with `GAMES_BATCH_SIZE = 100` and `USERS_BATCH_SIZE = 50`.

  * Sets the `FETCH_USER_ACHIEVEMENTS = False` flag by default, noting that extracting user achievements is computationally expensive.

* **Execution Flow:**

  1. Executes `sync_users()` to load and update player profiles.

  2. Executes `sync_games()` to extract and update the video game catalog.

  3. Executes `refresh_eda_views()` if the `REFRESH_EDA_VIEWS` flag is active, which runs an SQL script (`eda_refresh_levels()`) to update materialized views required by the R Shiny dashboard; this step is designed to be non-fatal in case of an error.

## `sync_data.py` (Extraction and Transformation Logic)

* **Purpose:** Coordinates API requests, applies transformation rules to the fetched JSONs, and prepares lists of dictionaries for the loader.

* **Game Synchronization (`sync_games`):**

  * Implements a resume system in the `load_games` function, reading local files (`page_{page}.json`) from a previous checkpoint to avoid consuming API quotas by downloading data that already exists in the environment.

  * Retrieves an array of missing `app_id`s from the database and iterates over them, extracting their details (`get_app_details`) and global achievement schema (`get_synced_game_achievements`).

* **User Synchronization (`sync_users`):**

  * Loads seed Steam IDs from the local file `data/seed_steam_ids.txt`, verifying against the database to process only pending or incomplete users.

  * Identifies private profiles or users without public games, updating the corresponding flags (`has_public_games`, `has_public_achievements`) without interrupting the execution.

  * If `FETCH_USER_ACHIEVEMENTS` is true, it uses asynchronous execution (`asyncio`) to fetch achievements from multiple games for a user concurrently. (Fetching achievements are very expensive on API calls)

## `loader.py` (Database and Insertion Layer)

* **Purpose:** Centralizes communication with PostgreSQL 16 and optimizes bulk write operations using the `execute_batch` function from `psycopg2.extras`.

* **Secure Connection Management:**

  * Builds the connection string exclusively by reading environment variables (`DB_HOST`, `DB_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`).

  * The `get_connection` function implements a fault-tolerance mechanism with a maximum of 5 retries and a 2-second delay between each, preventing catastrophic failures if the PostgreSQL container takes time to start.

* **Upsert Operations (Insert or Update):**

  * All loading functions (`upsert_games_batch`, `upsert_achievements_batch`, `upsert_users_batch`, etc.) use SQL queries with the `ON CONFLICT DO UPDATE SET` clause to guarantee data idempotency and update review metrics or playtimes without creating duplicates.

  * **Referential Integrity Management:** When loading a user's game library (`upsert_user_games_batch`) or their unlocked achievements (`upsert_user_achievements_batch`), the script first performs a contingency insertion of the parent game or achievement (`ON CONFLICT DO NOTHING`) to avoid foreign key errors if the general game catalog does not yet have those records.

## `api/endpoints.py` (API Route Registry)

* **Purpose:** Acts as a centralized dictionary for all external API endpoints used in the project.
* **Structure:** Groups URIs by their respective Steam Web API services (e.g., `IStoreService`, `ISteamUserStats`, `IPlayerService`, `ISteamUser`). 
* **Importance:** Hardcoding URLs across different modules makes code brittle. Keeping them here ensures that if Steam updates an endpoint version (e.g., from `v1` to `v2`), it only needs to be updated in one place.

## `api/steam_api.py` (Network and Data Normalization Layer)

* **Purpose:** Manages all direct HTTP interactions with the Steam API and SteamSpy, handling rate limits, data extraction, and structural transformations.
* **Network & Rate Limit Management:**
  * **Exponential Backoff:** Functions like `get_app_details` implement robust retry logic. If a `429 Too Many Requests` or `403 Forbidden` is encountered, it waits longer with each subsequent attempt to avoid IP bans.
  * **Asynchronous Execution:** Uses `aiohttp` and `asyncio.Semaphore` in `fetch_user_achievements_concurrently` to limit concurrent requests while drastically speeding up the retrieval of user achievements.
* **Data Collection Strategies:**
  * **User Discovery (Snowballing):** The `generate_steam_seed_ids` function uses a Breadth-First Search (BFS) approach. It reads initial seed IDs, fetches their friend lists, and crawls outward to dynamically discover new valid users for the database.
  * **Resumable Downloads:** `steamspy_download_all_pages_resumable` ensures that if a bulk download of the SteamSpy catalog fails midway, it can resume from the last successful page rather than starting over.
* **Data Cleaning & Normalization:**
  * **HTML Parsing:** The Steam API notoriously returns messy HTML inside JSON string fields (especially in game descriptions and PC requirements). Functions like `parse_requirements` use Regular Expressions to extract precise metrics (like `memory_gb` and `storage_gb`) from unstructured HTML `<li>` tags.
  * **Schema Transformation:** Functions prefixed with `transform_` (e.g., `transform_game_details`, `transform_user`) map the raw, nested API responses directly to flat dictionaries that match the PostgreSQL database tables precisely.

---

## Known Issues

* **User Achievements Bottleneck:** Fetching user achievements is highly rate-limited by Steam. Even with async requests and concurrency limits, scraping achievements for thousands of users with large libraries takes a significant amount of time.
* **API Rate Limiting (429 Errors):** The Steam API has strict, undocumented rate limits for endpoints like `appdetails`. While the backoff logic prevents crashes, prolonged scraping sessions will inevitably hit these limits and stall the pipeline temporarily.
* **Private User Profiles:** Many Steam users have private profiles or hide their game details. The pipeline handles this gracefully by flagging `is_public=False` or `has_public_games=False`, but this reduces the volume of actionable playtime data collected.
* **Inconsistent Steam Data Structures:** Steam's store data relies heavily on publisher input, leading to highly irregular formats in fields like release dates and PC requirements. The regex parsers do their best to clean the data, but edge cases might occasionally slip through as null values.