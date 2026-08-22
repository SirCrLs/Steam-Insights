package models

import io.circe.Codec

final case class Achievement(
  appId: Int,
  achievementKey: String,
  displayName: Option[String],
  achievementDesc: Option[String],
  globalUnlockPct: Option[BigDecimal]
) derives Codec.AsObject