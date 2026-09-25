package repository

import models.SteamId
import models.User
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import java.time.{LocalDate, LocalDateTime}

class UserRepository:

  def findAll(limit: Int, offset: Int): ConnectionIO[List[User]] =
    sql"""
      SELECT 
        u.steam_id, u.persona_name, u.profile_url, u.avatar_url, u.country_code, u.account_created,
        u.is_public, u.has_public_games, u.has_public_achievements, u.games_fetched, u.fetched_at
      FROM users u
      JOIN (
        SELECT steam_id 
        FROM users 
        ORDER BY steam_id 
        LIMIT $limit OFFSET $offset
      ) AS t ON u.steam_id = t.steam_id
      ORDER BY u.steam_id
    """.query[User].to[List]

  def count: ConnectionIO[Long] =
    sql"SELECT COUNT(*) FROM users".query[Long].unique

  def findById(steamId: SteamId): ConnectionIO[Option[User]] = 
    sql"""
      SELECT
        steam_id, persona_name, profile_url, avatar_url, country_code, account_created,
        is_public,has_public_games, has_public_achievements, games_fetched, fetched_at
      FROM users
      WHERE steam_id = ${steamId.value}
    """.query[User].option
  
  def create(user : User): ConnectionIO[Int] =
    sql"""
      INSERT INTO users (
        steam_id, persona_name, profile_url, avatar_url, country_code, account_created,
        is_public, has_public_games, has_public_achievements, games_fetched,  fetched_at
      ) VALUES (
        ${user.steamId.value}, ${user.personaName}, ${user.profileUrl}, ${user.avatarUrl},
        ${user.countryCode}, ${user.accountCreated}, ${user.isPublic}, ${user.fetchedAt},
        ${user.hasPublicGames}, ${user.hasPublicAchievements}, ${user.gamesFetched}
      )
    """.update.run

  def update(steamId : SteamId, user : User): ConnectionIO[Int] =
    sql"""
      UPDATE users SET
        persona_name = ${user.personaName}, 
        profile_url = ${user.profileUrl}, 
        avatar_url = ${user.avatarUrl}, 
        country_code = ${user.countryCode}, 
        account_created = ${user.accountCreated},
        is_public = ${user.isPublic}, 
        has_public_games = ${user.hasPublicGames}, 
        has_public_achievements = ${user.hasPublicAchievements}, 
        games_fetched = ${user.gamesFetched},
        fetched_at = ${user.fetchedAt}
      WHERE steam_id = ${steamId.value}
    """.update.run

  def delete(steamId: SteamId):ConnectionIO[Int] =
    sql"""
      DELETE FROM users WHERE steam_id = ${steamId.value}
    """.update.run
    