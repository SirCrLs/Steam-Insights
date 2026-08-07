from psycopg2.extras import execute_batch

def upsert_game_stubs(conn, game_stub_rows, page_size=1000):
    """
    Inserts a batch of a basic list of games (app_id + name).
    """
    if not game_stub_rows:
        return

    query = """
        INSERT INTO games (app_id, name)
        VALUES (%(app_id)s, %(name)s)
        ON CONFLICT (app_id) DO UPDATE SET
            name = EXCLUDED.name;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, game_stub_rows, page_size=page_size)

def get_all_app_ids(conn) -> list[int]:
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
            processor,
            graphics,
            ram_requirement,
            storage_requirement,
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
            %(processor)s,
            %(graphics)s,
            %(ram_requirement)s,
            %(storage_requirement)s,
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
            processor = EXCLUDED.processor,
            graphics = EXCLUDED.graphics,
            ram_requirement = EXCLUDED.ram_requirement,
            storage_requirement = EXCLUDED.storage_requirement,
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
            fetched_at = EXCLUDED.fetched_at;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, games_batch, page_size=page_size)

# loader.py
from psycopg2.extras import execute_batch

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
        is_public
    )
    VALUES (
        %(steam_id)s, 
        %(persona_name)s, 
        %(profile_url)s, 
        %(avatar_url)s, 
        %(country_code)s, 
        %(account_created)s, 
        %(is_public)s
    )
    ON CONFLICT (steam_id) DO UPDATE SET
        persona_name = EXCLUDED.persona_name,
        profile_url = EXCLUDED.profile_url,
        avatar_url = EXCLUDED.avatar_url,
        country_code = EXCLUDED.country_code,
        is_public = EXCLUDED.is_public;
"""
    with conn.cursor() as cursor:
        execute_batch(cursor, query, user_rows, page_size=500)

def upsert_user_games(conn, steam_id, user_games_rows):
    """Inserta o actualiza los juegos de un usuario en lote."""
    if not user_games_rows:
        return

    query = """
        INSERT INTO user_games (
            steam_id, 
            app_id, 
            playtime_forever, 
            playtime_2weeks
        )
        VALUES (
            %(steam_id)s, 
            %(app_id)s, 
            %(playtime_forever)s, 
            %(playtime_2weeks)s
        )   
        ON CONFLICT (steam_id, app_id) DO UPDATE SET
            playtime_forever = EXCLUDED.playtime_forever,
            playtime_2weeks = EXCLUDED.playtime_2weeks;
    """

    with conn.cursor() as cursor:
        execute_batch(cursor, query, user_games_rows, page_size=500)

def upsert_user_achievements(conn, ach_rows):
    """Inserta o actualiza los logros en lote."""
    if not ach_rows:
        return

    query = """
        INSERT INTO user_achievements (steam_id, app_id, achievement_name, unlocked)
        VALUES (%(steam_id)s, %(app_id)s, %(achievement_name)s, %(unlocked)s)
        ON CONFLICT (steam_id, app_id, achievement_name) DO UPDATE;
    """
    with conn.cursor() as cursor:
        execute_batch(cursor, query, ach_rows, page_size=500)