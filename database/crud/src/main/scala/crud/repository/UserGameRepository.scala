package repository

import models.UserGame
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*

object UserGameRepository:
  
  def findGamesBySteamId(steamId: Long): ConnectionIO[List[UserGame]] =
    sql"""
      SELECT 
        steam_id, app_id, playtime_forever, playtime_2weeks, achievements_status
      FROM user_games
      WHERE steam_id = $steamId
      ORDER BY playtime_forever DESC
    """.query[UserGame].to[List]
  
  def findOne(steamId: Long, appId: Int): ConnectionIO[Option[UserGame]] =
    sql"""
      SELECT 
        steam_id, app_id, playtime_forever, playtime_2weeks, achievements_status
      FROM user_games
      WHERE steam_id = $steamId AND game_id = $appId
    """.query[UserGame].option
  
  def upsert(userGame: UserGame): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_games (
        steam_id, app_id, playtime_forever, playtime_2weeks, achievements_status
      ) VALUES (
        ${userGame.steamId}, ${userGame.appId}, ${userGame.playtimeForever}, 
        ${userGame.playtime2weeks}, ${userGame.achievementsStatus}
      )
      ON CONFLICT (steam_id, game_id) DO UPDATE SET
        playtime_forever = EXCLUDED.playtime_forever,
        playtime_2weeks = EXCLUDED.playtime_2weeks,
        achievements_status = EXCLUDED.achievements_status
    """.update.run

  def delete(steamId: Long, gameId: Int): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_games 
      WHERE steam_id = $steamId AND game_id = $gameId
    """.update.run