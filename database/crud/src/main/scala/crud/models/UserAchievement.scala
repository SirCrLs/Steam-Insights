package models

import java.time.LocalDate
import io.circe.Codec
import doobie.Read
import doobie.postgres.implicits._

final case class UserAchievement(
  steamId: SteamId,
  appId: Int,
  achievementKey: String,
  unlocktime: Option[LocalDate]
) derives Codec.AsObject

object UserAchievement {
  given userAchievementRead: Read[UserAchievement] =
    Read[(Long, Int, String, Option[LocalDate])].map { case (sId, appId, key, time) =>
      UserAchievement(SteamId(sId), appId, key, time)
    }
}