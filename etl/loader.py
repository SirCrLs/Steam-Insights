import os
import time
import logging
import psycopg2
from psycopg2.extras import execute_batch

logger = logging.getLogger(__name__)

def get_connection(retries: int = 5, delay: int = 2):
    """
    Creates and returns a connection to the data base PostgreSQL 
    """
    host = os.environ.get("DB_HOST", "postgres")
    port = os.environ.get("DB_PORT", "5432")
    dbname = os.environ.get("POSTGRES_DB", "steam_db")
    user = os.environ.get("POSTGRES_USER", "postgres")
    password = os.environ.get("POSTGRES_PASSWORD", "")

    connection_string = f"host={host} port={port} dbname={dbname} user={user} password={password}"

    for attempt in range(1, retries + 1):
        try:
            conn = psycopg2.connect(connection_string, connect_timeout=10)
            logger.info(f"Connection succesfull ({host}:{port}/{dbname})")
            return conn
        except psycopg2.OperationalError as e:
            logger.warning(f"Attempt {attempt}/{retries} failed to connect to PostgreSQL: {e}")
            if attempt == retries:
                logger.error("Connection to DB failed.")
                raise e
            time.sleep(delay)

def get_game_name(conn, app_id):
    """
    Obtains name from app_id.
    """
    query = "SELECT name FROM games WHERE app_id = %s;"
    with conn.cursor() as cursor:
        cursor.execute(query, (app_id,))
        result = cursor.fetchone()
        if result:
            return result[0]
    return None

def upsert_game_stubs(conn, game_stub_rows, page_size=1000):
    """
    Inserts or updates a batch of basic game data (app_id, name, owners range, and review metrics).
    """
    if not game_stub_rows:
        return

    query = """
        INSERT INTO games (
            app_id, 
            name, 
            owners_min, 
            owners_max, 
            positive_reviews, 
            negative_reviews, 
            total_reviews, 
            approval_rate
        )
        VALUES (
            %(app_id)s, 
            %(name)s, 
            %(owners_min)s, 
            %(owners_max)s, 
            %(positive_reviews)s, 
            %(negative_reviews)s, 
            %(total_reviews)s, 
            %(approval_rate)s
        )
        ON CONFLICT (app_id) DO UPDATE SET
            name = EXCLUDED.name,
            owners_min = EXCLUDED.owners_min,
            owners_max = EXCLUDED.owners_max,
            positive_reviews = EXCLUDED.positive_reviews,
            negative_reviews = EXCLUDED.negative_reviews,
            total_reviews = EXCLUDED.total_reviews,
            approval_rate = EXCLUDED.approval_rate,
            fetched_at = now();
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, game_stub_rows, page_size=page_size)

def get_all_app_ids_null(conn) -> list[int]:
    """
    Obtains app_id from the table 'games' which dont have details
    checking if 'short_description' is empty or NULL.
    """
    query = """
        SELECT app_id 
        FROM games 
        WHERE short_description IS NULL 
           OR TRIM(short_description) = ''
    """

    with conn.cursor() as cursor:
        cursor.execute(query)
        rows = cursor.fetchall()

    return [row[0] for row in rows]

def upsert_games_batch(conn, games_batch, page_size=100):
    """
    Insert o update the game details from the game list.
    
    :param conn: Conection to PostgreSQL.
    :param games_batch: game list with details.
    :param page_size: batch size.
    """
    if not games_batch:
        return

    for row in games_batch:
        if row.get("name") is None:
            row["name"] = get_game_name(conn, row["app_id"])

    query = """
        INSERT INTO games (
            app_id,
            name,
            short_description,
            genres,
            categories,
            supported_languages,
            header_image,
            pc_requirements_minimum,
            pc_requirements_recommended,
            processor_minimum,
            processor_recommended,
            graphics_minimum,
            graphics_recommended,
            ram_minimum_gb,
            ram_recommended_gb,
            storage_minimum_gb,
            storage_recommended_gb,
            developers,
            is_on_windows,
            is_on_mac,
            is_on_linux,
            metacritic_score,
            release_date,
            price_usd,
            is_free,
            rating,
            total_achievements,
            recommendations,
            fetched_at
        )
        VALUES (
            %(app_id)s,
            %(name)s,
            %(short_description)s,
            %(genres)s,
            %(categories)s,
            %(supported_languages)s,
            %(header_image)s,
            %(pc_requirements_minimum)s,
            %(pc_requirements_recommended)s,
            %(processor_minimum)s,
            %(processor_recommended)s,
            %(graphics_minimum)s,
            %(graphics_recommended)s,
            %(ram_minimum_gb)s,
            %(ram_recommended_gb)s,
            %(storage_minimum_gb)s,
            %(storage_recommended_gb)s,
            %(developers)s,
            %(is_on_windows)s,
            %(is_on_mac)s,
            %(is_on_linux)s,
            %(metacritic_score)s,
            %(release_date)s,
            %(price_usd)s,
            %(is_free)s,
            %(rating)s,
            %(total_achievements)s,
            %(recommendations)s,
            %(fetched_at)s
        )
        ON CONFLICT (app_id) DO UPDATE SET
            name = EXCLUDED.name,
            short_description = EXCLUDED.short_description,
            genres = EXCLUDED.genres,
            categories = EXCLUDED.categories,
            supported_languages = EXCLUDED.supported_languages,
            header_image = EXCLUDED.header_image,
            pc_requirements_minimum = EXCLUDED.pc_requirements_minimum,
            pc_requirements_recommended = EXCLUDED.pc_requirements_recommended,
            processor_minimum = EXCLUDED.processor_minimum,
            processor_recommended = EXCLUDED.processor_recommended,
            graphics_minimum = EXCLUDED.graphics_minimum,
            graphics_recommended = EXCLUDED.graphics_recommended,
            ram_minimum_gb = EXCLUDED.ram_minimum_gb,
            ram_recommended_gb = EXCLUDED.ram_recommended_gb,
            storage_minimum_gb = EXCLUDED.storage_minimum_gb,
            storage_recommended_gb = EXCLUDED.storage_recommended_gb,
            developers = EXCLUDED.developers,
            is_on_windows = EXCLUDED.is_on_windows,
            is_on_mac = EXCLUDED.is_on_mac,
            is_on_linux = EXCLUDED.is_on_linux,
            metacritic_score = EXCLUDED.metacritic_score,
            release_date = EXCLUDED.release_date,
            price_usd = EXCLUDED.price_usd,
            is_free = EXCLUDED.is_free,
            rating = EXCLUDED.rating,
            total_achievements = EXCLUDED.total_achievements,
            recommendations = EXCLUDED.recommendations,
            fetched_at = EXCLUDED.fetched_at;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, games_batch, page_size=page_size)

def upsert_achievements_batch(conn, achievement_rows, page_size=500):
    """
    Inserts or updates a batch of game achievements in PostgreSQL.
    """
    if not achievement_rows:
        return

    query = """
        INSERT INTO achievements (
            app_id,
            achievement_key,
            display_name,
            achievement_desc,
            global_unlock_pct
        )
        VALUES (
            %(app_id)s,
            %(achievement_key)s,
            %(display_name)s,
            %(achievement_desc)s,
            %(global_unlock_pct)s
        )
        ON CONFLICT (app_id, achievement_key) DO UPDATE SET
            display_name = EXCLUDED.display_name,
            achievement_desc = EXCLUDED.achievement_desc,
            global_unlock_pct = EXCLUDED.global_unlock_pct;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, achievement_rows, page_size=page_size)

def upsert_users_batch(conn, user_rows):
    """Inserts a list of users."""
    if not user_rows:
        return

    query = """
    INSERT INTO users (
        steam_id, 
        persona_name, 
        profile_url, 
        avatar_url, 
        country_code, 
        account_created, 
        is_public,
        games_fetched
    )
    VALUES (
        %(steam_id)s, 
        %(persona_name)s, 
        %(profile_url)s, 
        %(avatar_url)s, 
        %(country_code)s, 
        %(account_created)s, 
        %(is_public)s,
        CASE WHEN %(is_public)s = FALSE THEN FALSE ELSE NULL END
    )
    ON CONFLICT (steam_id) DO UPDATE SET
        persona_name = EXCLUDED.persona_name,
        profile_url = EXCLUDED.profile_url,
        avatar_url = EXCLUDED.avatar_url,
        country_code = EXCLUDED.country_code,
        is_public = EXCLUDED.is_public,
        games_fetched = CASE 
            WHEN EXCLUDED.is_public = FALSE THEN FALSE 
            ELSE users.games_fetched 
        END;
    """
    with conn.cursor() as cursor:
        execute_batch(cursor, query, user_rows, page_size=500)

def update_users_status_batch(conn, users_status_rows):
    """Inserta o actualiza las banderas de los usuarios en el lote."""
    if not users_status_rows:
        return

    query = """
    INSERT INTO users (
        steam_id, 
        has_public_games, 
        has_public_achievements, 
        games_fetched
    )
    VALUES (
        %(steam_id)s, 
        %(has_public_games)s, 
        %(has_public_achievements)s, 
        %(games_fetched)s
    )
    ON CONFLICT (steam_id) DO UPDATE SET
        has_public_games = EXCLUDED.has_public_games,
        has_public_achievements = EXCLUDED.has_public_achievements,
        games_fetched = EXCLUDED.games_fetched;
    """
    
    with conn.cursor() as cursor:
        execute_batch(cursor, query, users_status_rows, page_size=500)
def upsert_user_games_batch(conn, user_games_rows):
    """Inserts user games in a batch, ensuring parent games exist first."""
    if not user_games_rows:
        return

    unique_games = [
        {"app_id": app_id}
        for app_id in {row["app_id"] for row in user_games_rows}
    ]

    # Insert games that don't exist on DB
    games_query = """
        INSERT INTO games (app_id, name)
        VALUES (%(app_id)s, 'Not in DB')
        ON CONFLICT (app_id) DO NOTHING;
    """

    user_games_query = """
        INSERT INTO user_games (
            steam_id, 
            app_id, 
            playtime_forever, 
            playtime_2weeks,
            achievements_status
        )
        VALUES (
            %(steam_id)s, 
            %(app_id)s, 
            %(playtime_forever)s, 
            %(playtime_2weeks)s,
            %(achievements_status)s
        )   
        ON CONFLICT (steam_id, app_id) DO UPDATE SET
            playtime_forever = EXCLUDED.playtime_forever,
            playtime_2weeks = EXCLUDED.playtime_2weeks,
            achievements_status = EXCLUDED.achievements_status;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, games_query, unique_games, page_size=500)
        execute_batch(cursor, user_games_query, user_games_rows, page_size=500)

def upsert_user_achievements_batch(conn, ach_rows):
    """Inserts parent achievement records first, then user achievements in batch."""
    if not ach_rows:
        return

    unique_achievements = [
        {"app_id": app_id, "achievement_key": ach_key}
        for app_id, ach_key in {
            (row["app_id"], row["achievement_key"]) for row in ach_rows
        }
    ]

    # Insert missing achievements
    achievements_query = """
        INSERT INTO achievements (app_id, achievement_key, display_name)
        VALUES (%(app_id)s, %(achievement_key)s, NULL)
        ON CONFLICT (app_id, achievement_key) DO NOTHING;
    """

    # Insert user achievements
    user_achievements_query = """
        INSERT INTO user_achievements (
            steam_id, 
            app_id, 
            achievement_key, 
            unlock_time
        )
        VALUES (
            %(steam_id)s, 
            %(app_id)s, 
            %(achievement_key)s, 
            %(unlock_time)s
        )
        ON CONFLICT (steam_id, app_id, achievement_key) DO UPDATE SET
            unlock_time = EXCLUDED.unlock_time;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, achievements_query, unique_achievements, page_size=500)
        execute_batch(cursor, user_achievements_query, ach_rows, page_size=500)