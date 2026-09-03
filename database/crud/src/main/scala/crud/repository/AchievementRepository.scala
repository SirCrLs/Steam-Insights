package repository

import models.Achievement
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*

class AchievementRepository:
  
  def findAll(limit: Int = 100, offset: Int = 0): ConnectionIO[List[Achievement]] =
    sql"""
      SELECT app_id, achievement_key, display_name, achievement_desc, global_unlock_pct
      FROM achievements
      ORDER BY app_id ASC, achievement_key ASC
      LIMIT $limit OFFSET $offset
    """.query[Achievement].to[List]

  def count: ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM achievements
    """.query[Int].unique

  def findByAppId(appId: Int, limit: Int = 100, offset: Int = 0): ConnectionIO[List[Achievement]] = 
    sql"""
      SELECT 
        app_id, 
        achievement_key, 
        display_name, 
        achievement_desc, 
        global_unlock_pct
      FROM achievements
      WHERE app_id = $appId
      ORDER BY achievement_key ASC
      LIMIT $limit OFFSET $offset
    """.query[Achievement].to[List]

  def countByAppId(appId: Int): ConnectionIO[Int] =
    sql"""
      SELECT COUNT(*) 
      FROM achievements 
      WHERE app_id = $appId
    """.query[Int].unique

  def create(achievement: Achievement): ConnectionIO[Int] = 
    sql"""
      INSERT INTO achievements (
        app_id, 
        achievement_key, 
        display_name, 
        achievement_desc, 
        global_unlock_pct
      )
      VALUES (
        ${achievement.appId}, ${achievement.achievementKey}, ${achievement.displayName},
        ${achievement.achievementDesc}, ${achievement.globalUnlockPct}
      )
    """.update.run
  
  def update(achievement: Achievement, achievementKey : String, appId : Int): ConnectionIO[Int] = 
    sql"""
      UPDATE achievements SET
        display_name = ${achievement.displayName}, 
        achievement_desc = ${achievement.achievementDesc}, 
        global_unlock_pct = ${achievement.globalUnlockPct}
      WHERE achievement_key = $achievementKey AND app_id = $appId
    """.update.run

  def delete(appId : Int, achievementKey : String): ConnectionIO[Int] = 
    sql"""
      DELETE FROM achievements WHERE achievement_key = $achievementKey AND app_id = $appId
    """.update.run
