package models

import java.time.LocalDate
import io.circe.Codec

final case class UserAchievement(
  steamId: Long,
  appId: Int,
  achievementKey: String,
  unlocktime: Option[LocalDate]
) derives Codec.AsObject