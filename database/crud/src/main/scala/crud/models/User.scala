package models

import java.time.LocalDateTime
import io.circe.Codec
import doobie.Read
import doobie.postgres.implicits._

final case class User(
  steamId: SteamId,
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

object User {
  given userRead: Read[User] =
    Read[(Long, 
      Option[String], 
      Option[String], 
      Option[String], 
      Option[String], 
      Option[LocalDateTime], 
      Option[Boolean], 
      Option[Boolean], 
      Option[Boolean], 
      Option[Boolean], 
      Option[LocalDateTime])].map { 
      case (sId, 
        personaName, 
        profileUrl, 
        avatarUrl, 
        countryCode, 
        accountCreated, 
        isPublic, 
        hasPublicGames, 
        hasPublicAchievements, 
        gamesFetched, 
        fetchedAt) =>
        User(SteamId(sId), personaName, profileUrl, avatarUrl, countryCode, 
          accountCreated, isPublic, hasPublicGames, hasPublicAchievements, gamesFetched, fetchedAt)
    }
}