package routes

import cats.effect.Async
import cats.syntax.all.*
import io.circe.syntax.*
import io.circe.generic.auto.*
import org.http4s.*
import org.http4s.dsl.Http4sDsl
import org.http4s.circe.*
import org.http4s.server.Router
import doobie.implicits.toConnectionIOOps
import doobie.util.transactor.Transactor
import org.http4s.circe.CirceEntityEncoder.*
import org.http4s.circe.CirceEntityDecoder.*

import models.User
import models.UserGame
import models.UserAchievement
import repository.UserRepository
import repository.UserGameRepository
import repository.UserAchievementRepository

// brings userRepo, userGameRepo and userAchievementRepo
class UserRoutes[F[_]: Async](
  userRepository: UserRepository, 
  userGamesRepo: UserGameRepository,
  userAchievementsRepo: UserAchievementRepository,
  xa : Transactor[F]
) extends Http4sDsl[F]:

  val GamesURL = "games"
  val AchievementsURL = "achievements"

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:
    // ==   USERS   ==
    //GET all users
    case GET -> Root :? OffsetParam(offset) =>
      for
        users <- userRepository.findAll(offset.getOrElse(0)).transact(xa)
        resp  <- Ok(users)
      yield resp

    //GET user by steamid
    case GET -> Root / LongVar(steamid) =>
      for
        maybeUser <- userRepository.findById(steamid).transact(xa)
        resp <- maybeUser match
          case Some(user) => Ok(user)
          case None => NotFound(s"User not found: steamID = $steamid")
      yield resp

    //POST create user
    case req @ POST -> Root =>
      for
        newUser <- req.as[User]
        rowsInserted <- userRepository.create(newUser).transact(xa)
        resp <- if rowsInserted > 0 then
          Created(Map("message" -> "Success : ", "count" -> rowsInserted.toString))
        else
          BadRequest(Map("error" -> "Create failed"))
      yield resp

    //PUT update a user
    case req @ PUT -> Root / LongVar(steamid) =>
      for
        userUpdate <- req.as[User]
        rowsUpdated <- userRepository.update(steamid, userUpdate).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"User $steamid updated."))
        else
          NotFound(Map("error" -> s"Update failed: User $steamid does not exist"))
      yield resp

    // DELETE user by id
    case DELETE -> Root / LongVar(steamid) =>
      for
        rowsDeleted <- userRepository.delete(steamid).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"Delete failed: user $steamid does not exist"))
      yield resp

    // ==   UserGame   ==
    // GET all games from user
    case GET -> Root / LongVar(steamId) / GamesURL :? OffsetParam(offset) =>
      for
        games <- userGamesRepo.findGamesBySteamId(steamId, offset.getOrElse(0)).transact(xa)
        resp  <- Ok(games)
      yield resp

    // GET one game from user
    case GET -> Root / LongVar(steamid) / GamesURL / IntVar(appid)=>
      for
        maybeGame <- userGamesRepo.findOne(steamid,appid).transact(xa)
        resp <- maybeGame match
          case Some(userGame) => Ok(userGame)
          case None => NotFound(s"Game not found: ID $appid")
      yield resp

    // POST upsert a game for user
    case req @ POST -> Root / LongVar(steamId) / GamesURL =>
      for
        userGame <- req.as[UserGame]
        rowsInserted <- userGamesRepo.upsert(userGame).transact(xa)
        resp <- if rowsInserted > 0 then
          Created(Map("message" -> s"Game upserted for user $steamId successfully"))
        else
          BadRequest(Map("error" -> "Upsert failed."))
      yield resp

    // DELETE a game from user library
    case DELETE -> Root / LongVar(steamId) / GamesURL / IntVar(appid) =>
      for
        rowsDeleted <- userGamesRepo.delete(steamId, appid).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"Game $appid not found on library of user $steamId"))
      yield resp


    // ==   UserAchievements   ==
    // GET all achievements from a user
    case GET -> Root / LongVar(steamId) / AchievementsURL :? OffsetParam(offset) =>
      for
        achievements <- userAchievementsRepo.findAllBySteamId(steamId, offset.getOrElse(0)).transact(xa)
        resp         <- Ok(achievements)
      yield resp

    // GET all achievements of user for an specific game
    case GET -> Root / LongVar(steamId) / AchievementsURL / IntVar(appid) :? OffsetParam(offset) =>
      for
        achievements <- userAchievementsRepo.findBySteamIdAndAppId(steamId, appid, offset.getOrElse(0)).transact(xa)
        resp         <- Ok(achievements)
      yield resp

    // PUT Upsert an achievement
    case req @ PUT -> Root / LongVar(steamId) / AchievementsURL =>
      for
        achUpdate   <- req.as[UserAchievement]
        rowsUpdated <- userAchievementsRepo.upsert(achUpdate).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"Achievement upserted successfully for user $steamId"))
        else
          BadRequest(Map("error" -> s"Failed to upsert achievement for user $steamId"))
      yield resp
  
    // DELETE all achievements from a game
    case DELETE -> Root / LongVar(steamId) / AchievementsURL / IntVar(appId) =>
      for
        rowsDeleted <- userAchievementsRepo.deleteBySteamIdAndAppId(steamId, appId).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"Achievements not found for $appId"))
      yield resp

    // DELETE one specific achievement
    case DELETE -> Root / LongVar(steamId) / AchievementsURL / IntVar(appId) / achievementKey =>
      for
        rowsDeleted <- userAchievementsRepo.deleteByKey(steamId, appId, achievementKey).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"ahcievement = $achievementKey not found for game $appId and user $steamId"))
      yield resp