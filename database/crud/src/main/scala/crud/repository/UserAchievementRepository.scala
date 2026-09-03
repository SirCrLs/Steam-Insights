package repository

import models.UserAchievement
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import java.time.LocalDate

class UserAchievementRepository:

  def findAllBySteamId(steamId: Long, offset: Int = 0): ConnectionIO[List[UserAchievement]] =
    sql"""
      SELECT steam_id, app_id, achievement_key, unlock_time
      FROM user_achievements
      WHERE steam_id = $steamId
      ORDER BY unlock_time DESC NULLS LAST, achievement_key ASC
      LIMIT 100 OFFSET $offset
    """.query[UserAchievement].to[List]

  def findBySteamIdAndAppId(steamId: Long, appId: Int, offset: Int = 0): ConnectionIO[List[UserAchievement]] =
    sql"""
      SELECT steam_id, app_id, achievement_key, unlock_time
      FROM user_achievements
      WHERE steam_id = $steamId AND app_id = $appId
      ORDER BY unlock_time DESC NULLS LAST, achievement_key ASC
      LIMIT 100 OFFSET $offset
    """.query[UserAchievement].to[List]

  def create(achievement: UserAchievement): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_achievements (
        steam_id, app_id, achievement_key, unlock_time
      ) VALUES (
        ${achievement.steamId},
        ${achievement.appId},
        ${achievement.achievementKey},
        ${achievement.unlocktime}
      )
    """.update.run

  def createMany(achievements: List[UserAchievement]): ConnectionIO[Int] =
    val sql = """
      INSERT INTO user_achievements (
        steam_id, app_id, achievement_key, unlock_time
      ) VALUES (?, ?, ?, ?)
    """
    Update[UserAchievement](sql).updateMany(achievements)

  def upsert(achievement: UserAchievement): ConnectionIO[Int] =
    sql"""
      INSERT INTO user_achievements (
        steam_id, app_id, achievement_key, unlock_time
      ) VALUES (
        ${achievement.steamId},
        ${achievement.appId},
        ${achievement.achievementKey},
        ${achievement.unlocktime}
      )
      ON CONFLICT (steam_id, app_id, achievement_key) 
      DO UPDATE SET unlocktime = EXCLUDED.unlock_time
    """.update.run

  def deleteBySteamIdAndAppId(steamId: Long, appId: Int): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_achievements
      WHERE steam_id = $steamId AND app_id = $appId
    """.update.run
  
  def deleteByKey(steamId: Long, appId: Int, achievementKey: String): ConnectionIO[Int] =
    sql"""
      DELETE FROM user_achievements
      WHERE steam_id = $steamId 
        AND app_id = $appId 
        AND achievement_key = $achievementKey
    """.update.run