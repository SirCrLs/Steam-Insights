package repository

import models.SteamId
import models.UserGame
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*

class UserGameRepository:

  def findAll(limit: Int = 100, offset: Int = 0): ConnectionIO[List[UserGame]] = 
    sql"""
      SELECT 
        ug.steam_id, 
        ug.app_id, 
        ug.playtime_forever, 
        ug.playtime_2weeks, 
        ug.achievements_status
      FROM user_games ug
      JOIN (
        SELECT steam_id, app_id 
        FROM user_games 
        ORDER BY steam_id ASC, app_id ASC
        LIMIT $limit OFFSET $offset
      ) AS t ON ug.steam_id = t.steam_id AND ug.app_id = t.app_id
      ORDER BY ug.steam_id ASC, ug.app_id ASC
    """.query[UserGame].to[List]

  def count: ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM user_games
    """.query[Int].unique
  
  def findGamesBySteamId(steamId: SteamId, limit: Int = 100, offset: Int = 0): ConnectionIO[List[UserGame]] = 
    sql"""
      SELECT 
        ug.steam_id, 
        ug.app_id, 
        ug.playtime_forever, 
        ug.playtime_2weeks, 
        ug.achievements_status
      FROM user_games ug
      JOIN (
        SELECT app_id 
        FROM user_games 
        WHERE steam_id = ${steamId.value}
        ORDER BY playtime_forever DESC, app_id ASC
        LIMIT $limit OFFSET $offset
      ) AS t ON ug.steam_id = ${steamId.value} AND ug.app_id = t.app_id
      ORDER BY ug.playtime_forever DESC, ug.app_id ASC
    """.query[UserGame].to[List]

  def countBySteamId(steamId: SteamId): ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM user_games 
      WHERE steam_id = ${steamId.value}
    """.query[Int].unique
  
  def findOne(steamId: SteamId, appId: Int): ConnectionIO[Option[UserGame]] =
    sql"""
      SELECT 
        steam_id, app_id, playtime_forever, playtime_2weeks, achievements_status
      FROM user_games
      WHERE steam_id = ${steamId.value} AND app_id = $appId
    """.query[UserGame].option
  
  def upsert(userGame: UserGame): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_games (
        steam_id, app_id, playtime_forever, playtime_2weeks, achievements_status
      ) VALUES (
        ${userGame.steamId.value}, ${userGame.appId}, ${userGame.playtimeForever}, 
        ${userGame.playtime2weeks}, ${userGame.achievementsStatus}
      )
      ON CONFLICT (steam_id, app_id) DO UPDATE SET
        playtime_forever = EXCLUDED.playtime_forever,
        playtime_2weeks = EXCLUDED.playtime_2weeks,
        achievements_status = EXCLUDED.achievements_status
    """.update.run

  def delete(steamId: SteamId, gameId: Int): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_games 
      WHERE steam_id = ${steamId.value} AND game_id = $gameId
    """.update.run