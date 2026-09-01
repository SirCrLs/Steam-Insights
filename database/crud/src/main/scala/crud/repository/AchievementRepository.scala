package repository

import models.Achievement
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*

class AchievementRepository:
  
  def findAll: ConnectionIO[List[Achievement]] =
    sql"""
      SELECT app_id, achievement_key, display_name, achievement_desc, global_unlock_pct
      FROM achievements
    """.query[Achievement].to[List]

  def findById(appId: Int): ConnectionIO[Option[Achievement]]= 
    sql"""
      SELECT 
        app_id, 
        achievement_key, 
        display_name, 
        achievement_desc, 
        global_unlock_pct
      FROM achievements
      WHERE app_id = $appId
    """.query[Achievement].option

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
