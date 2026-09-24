package repository

import models.UserAchievement
import models.SteamId
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import java.time.LocalDate

class UserAchievementRepository:

  def findAll(limit: Int = 100, offset: Int = 0): ConnectionIO[List[UserAchievement]] =
    sql"""
      SELECT 
        ua.steam_id, 
        ua.app_id, 
        ua.achievement_key, 
        ua.unlock_time
      FROM user_achievements ua
      JOIN (
        SELECT steam_id, app_id, achievement_key 
        FROM user_achievements 
        ORDER BY steam_id ASC, app_id ASC, achievement_key ASC
        LIMIT $limit OFFSET $offset
      ) AS t ON ua.steam_id = t.steam_id AND ua.app_id = t.app_id AND ua.achievement_key = t.achievement_key
      ORDER BY ua.steam_id ASC, ua.app_id ASC, ua.achievement_key ASC
    """.query[UserAchievement].to[List]

  def count: ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM user_achievements
    """.query[Int].unique

  def findAllBySteamId(steamId: SteamId, limit: Int = 100, offset: Int = 0): ConnectionIO[List[UserAchievement]] =
    sql"""
      SELECT 
        ua.steam_id, 
        ua.app_id, 
        ua.achievement_key, 
        ua.unlock_time
      FROM user_achievements ua
      JOIN (
        SELECT app_id, achievement_key 
        FROM user_achievements 
        WHERE steam_id = ${steamId.value}
        ORDER BY unlock_time DESC NULLS LAST, achievement_key ASC
        LIMIT $limit OFFSET $offset
      ) AS t ON ua.steam_id = ${steamId.value} AND ua.app_id = t.app_id AND ua.achievement_key = t.achievement_key
      ORDER BY ua.unlock_time DESC NULLS LAST, ua.achievement_key ASC
    """.query[UserAchievement].to[List]

  def countBySteamId(steamId: SteamId): ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM user_achievements 
      WHERE steam_id = ${steamId.value}
    """.query[Int].unique

  def findBySteamIdAndAppId(steamId: SteamId, appId: Int, limit: Int = 100, offset: Int = 0): ConnectionIO[List[UserAchievement]] =
    sql"""
      SELECT 
        ua.steam_id, 
        ua.app_id, 
        ua.achievement_key, 
        ua.unlock_time
      FROM user_achievements ua
      JOIN (
        SELECT achievement_key 
        FROM user_achievements 
        WHERE steam_id = ${steamId.value} AND app_id = $appId
        ORDER BY unlock_time DESC NULLS LAST, achievement_key ASC
        LIMIT $limit OFFSET $offset
      ) AS t ON ua.steam_id = ${steamId.value} AND ua.app_id = $appId AND ua.achievement_key = t.achievement_key
      ORDER BY ua.unlock_time DESC NULLS LAST, ua.achievement_key ASC
    """.query[UserAchievement].to[List]

  def countBySteamIdAndAppId(steamId: SteamId, appId: Int): ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM user_achievements 
      WHERE steam_id = ${steamId.value} AND app_id = $appId
    """.query[Int].unique

  def create(achievement: UserAchievement): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_achievements (
        steam_id, app_id, achievement_key, unlock_time
      ) VALUES (
        ${achievement.steamId.value},
        ${achievement.appId},
        ${achievement.achievementKey},
        ${achievement.unlocktime}
      )
    """.update.run

  def upsert(achievement: UserAchievement): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_achievements (
        steam_id, app_id, achievement_key, unlock_time
      ) VALUES (
        ${achievement.steamId.value},
        ${achievement.appId},
        ${achievement.achievementKey},
        ${achievement.unlocktime}
      )
      ON CONFLICT (steam_id, app_id, achievement_key) 
      DO UPDATE SET unlocktime = EXCLUDED.unlock_time
    """.update.run

  def deleteBySteamIdAndAppId(steamId: SteamId, appId: Int): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_achievements
      WHERE steam_id = ${steamId.value} AND app_id = $appId
    """.update.run
  
  def deleteByKey(steamId: SteamId, appId: Int, achievementKey: String): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_achievements
      WHERE steam_id = ${steamId.value} 
        AND app_id = $appId 
        AND achievement_key = $achievementKey
    """.update.run