package repository

import models.Achievement
import doobie.* 

object AchievementRepository:
  def findAll: ConnectionIO[List[Achievement]] =
    sql"""
      SELECT app_id, achievement_key, display_name, achievement_desc, global_unlock_pct
      FROM achievements
    """.query[Achievement].to[List]

  def findById(appId: Int): ConnectionIO[Option[Achievement]]= 
    sql"""
      SELECT app_id, achievement_key, display_name, achievement_desc, global_unlock_pct
      FROM achievements
      WHERE app_id = $appId
    """.query[Achievement].option

  def create(Achievement: Achievement): ConnectionIO[Int] = 
    sql"""
      INSERT INTO achievements (app_id, achievement_key, display_name, achievement_desc, global_unlock_pct)
      VALUES (${Achievement.appId}, ${Achievement.achievementKey}, ${Achievement.displayName},
        ${Achievement.achievementDesc}, ${Achievement.globalUnlockPct})
    """ 

