package repository

import models.Achievement
import doobie.* 

object AchievementRepository:
  def findAll: ConnectionIO[List[Achievement]] =
    sql"""
    SELECT
    FROM achievements
    """.query[Achievement].to[List]

