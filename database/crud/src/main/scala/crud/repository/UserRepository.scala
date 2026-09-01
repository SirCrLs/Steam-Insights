package repository

import models.User
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import java.time.{LocalDate, LocalDateTime}

class UserRepository:

  def findAll: ConnectionIO[List[User]] =
    sql"""
      SELECT 
        steam_id, persona_name, profile_url, avatar_url, country_code, account_created,
        is_public, fetched_at, has_public_games, has_public_achievements, games_fetched
      FROM users
    """.query[User].to[List]

  def findById(steamId: Long): ConnectionIO[Option[User]] = 
    sql"""
      SELECT
        steam_id, persona_name, profile_url, avatar_url, country_code, account_created,
        is_public, fetched_at, has_public_games, has_public_achievements, games_fetched
      FROM users
      WHERE steam_id = $steamId
    """.query[User].option
  
  def create(user : User): ConnectionIO[Int] =
    sql"""
      INSERT INTO users (
        steam_id, persona_name, profile_url, avatar_url, country_code, account_created,
        is_public, fetched_at, has_public_games, has_public_achievements, games_fetched
      ) VALUES (
        ${user.steamId}, ${user.personaName}, ${user.profileUrl}, ${user.avatarUrl},
        ${user.countryCode}, ${user.accountCreated}, ${user.isPublic}, ${user.fetchedAt},
        ${user.hasPublicGames}, ${user.hasPublicAchievements}, ${user.gamesFetched}
      )
    """.update.run

  def update(steamId : Long, user : User): ConnectionIO[Int] =
    sql"""
      UPDATE users SET
        persona_name = ${user.personaName}, 
        profile_url = ${user.profileUrl}, 
        avatar_url = ${user.avatarUrl}, 
        country_code = ${user.countryCode}, 
        account_created = ${user.accountCreated},
        is_public = ${user.isPublic}, 
        fetched_at = ${user.fetchedAt}, 
        has_public_games = ${user.hasPublicGames}, 
        has_public_achievements = ${user.hasPublicAchievements}, 
        games_fetched = ${user.gamesFetched}
      WHERE steam_id = $steamId
    """.update.run

  def delete(steamId: Long):ConnectionIO[Int] =
    sql"""
      DELETE FROM users WHERE steam_id = $steamId
    """.update.run
    