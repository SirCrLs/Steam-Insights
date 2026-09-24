package models

import io.circe.Codec
import doobie.Read

final case class UserGame(
  steamId: SteamId,
  appId: Int,
  playtimeForever: Option[Int],
  playtime2weeks: Option[Int],
  achievementsStatus: Option[String]
) derives Codec.AsObject

object UserGame {
  given userGameRead: Read[UserGame] =
    Read[(Long, Int, Option[Int], Option[Int], Option[String])].map { 
      case (sId, appId, ptForever, pt2weeks, achStatus) =>
        UserGame(SteamId(sId), appId, ptForever, pt2weeks, achStatus)
    }
}