package models

import java.time.LocalDateTime
import io.circe.Codec

final case class User(
  steamId: Long,
  personaName: Option[String],
  profileUrl: Option[String],
  avatarUrl: Option[String],
  countryCode: Option[String],
  accountCreated: Option[LocalDateTime],
  isPublic: Option[Boolean],
  hasPublicGames: Option[Boolean],
  hasPublicAchievements: Option[Boolean],
  gamesFetched: Option[Boolean],
  fetchedAt: Option[LocalDateTime]
) derives Codec.AsObject