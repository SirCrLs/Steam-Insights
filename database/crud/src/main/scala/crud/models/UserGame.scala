package models

import io.circe.Codec

final case class UserGame(
  steamId: Long,
  appId: Int,
  playtimeForever: Option[Int],
  playtime2weeks: Option[Int],
  achievementsStatus: Option[String]
) derives Codec.AsObject