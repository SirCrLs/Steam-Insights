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

import models.SteamId
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
    case GET -> Root :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        users <- userRepository.findAll(limit, offset).transact(xa)
        total <- userRepository.count.transact(xa)
        resp <- Ok(Map("total" -> total.asJson, "users" -> users.asJson))
      yield resp

    //GET user by steamid
    case GET -> Root / LongVar(rawSteamid) =>
      val steamid: SteamId = SteamId(rawSteamid)
      userRepository.findById(steamid).transact(xa).attempt.flatMap {
        case Right(Some(user)) => Ok(user)
        case Right(None)       => NotFound(Map("error" -> s"User not found: steamID = $steamid"))
        case Left(error)       => 
          error.printStackTrace()
          InternalServerError(Map("error" -> s"Database mapping error: ${error.getMessage}"))
      }

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
    case req @ PUT -> Root / LongVar(rawSteamid) =>
      val steamid: SteamId = SteamId(rawSteamid)
      for
        userUpdate <- req.as[User]
        rowsUpdated <- userRepository.update(steamid, userUpdate).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"User $steamid updated."))
        else
          NotFound(Map("error" -> s"Update failed: User $steamid does not exist"))
      yield resp

    // DELETE user by id
    case DELETE -> Root / LongVar(rawSteamid) =>
      val steamid: SteamId = SteamId(rawSteamid)
      userRepository.delete(steamid).transact(xa).attempt.flatMap {
        case Right(rowsDeleted) if rowsDeleted > 0 =>
          Ok(Map("message" -> s"User $steamid deleted successfully"))
          
        case Right(_) =>
          NotFound(Map("error" -> s"Delete failed: user $steamid does not exist"))
          
        case Left(error) =>
          InternalServerError(Map("error" -> s"Error deleting user: ${error.getMessage}"))
      }

    // ==   UserGame   ==
    // GET all user games
    case GET -> Root / "user-games" :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        games <- userGamesRepo.findAll(limit, offset).transact(xa)
        total <- userGamesRepo.count.transact(xa)
        resp  <- Ok(Map("total" -> total.asJson, "user_games" -> games.asJson))
      yield resp

    // GET all games from user
    case GET -> Root / LongVar(rawSteamid) / GamesURL :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val steamid: SteamId = SteamId(rawSteamid)
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        games <- userGamesRepo.findGamesBySteamId(steamid, limit, offset).transact(xa)
        total <- userGamesRepo.countBySteamId(steamid).transact(xa)
        resp  <- Ok(Map("total" -> total.asJson, "games" -> games.asJson))
      yield resp

    // GET one game from user
    case GET -> Root / LongVar(rawSteamid) / GamesURL / IntVar(appid)=>
      val steamid: SteamId = SteamId(rawSteamid)
      for
        maybeGame <- userGamesRepo.findOne(steamid,appid).transact(xa)
        resp <- maybeGame match
          case Some(userGame) => Ok(userGame)
          case None => NotFound(s"Game not found: ID $appid")
      yield resp

    // POST upsert a game for user
    case req @ POST -> Root / LongVar(rawSteamid) / GamesURL =>
      val steamid: SteamId = SteamId(rawSteamid)
      for
        userGame <- req.as[UserGame]
        rowsInserted <- userGamesRepo.upsert(userGame).transact(xa)
        resp <- if rowsInserted > 0 then
          Created(Map("message" -> s"Game upserted for user $steamid successfully"))
        else
          BadRequest(Map("error" -> "Upsert failed."))
      yield resp

    // DELETE a game from user library
    case DELETE -> Root / LongVar(rawSteamid) / GamesURL / IntVar(appid) =>
      val steamid: SteamId = SteamId(rawSteamid)
      userGamesRepo.delete(steamid, appid).transact(xa).attempt.flatMap {
        case Right(rowsDeleted) if rowsDeleted > 0 =>
          Ok(Map("message" -> s"Game $appid removed from library of user $steamid"))

        case Right(_) =>
          NotFound(Map("error" -> s"Game $appid not found on library of user $steamid"))

        case Left(error) =>
          InternalServerError(Map("error" -> s"Error removing game from library: ${error.getMessage}"))
      }


    // ==   UserAchievements   ==
    // GET all user achievements
    case GET -> Root / "user-achievements" :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        achievements <- userAchievementsRepo.findAll(limit, offset).transact(xa)
        total <- userAchievementsRepo.count.transact(xa)
        resp  <- Ok(Map("total" -> total.asJson, "user_achievements" -> achievements.asJson))
      yield resp
      
    // GET all achievements from a user
    case GET -> Root / LongVar(rawSteamid) / AchievementsURL :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val steamid: SteamId = SteamId(rawSteamid)
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        achievements <- userAchievementsRepo.findAllBySteamId(steamid, limit, offset).transact(xa)
        total <- userAchievementsRepo.countBySteamId(steamid).transact(xa)
        resp <- Ok(Map("total" -> total.asJson, "achievements" -> achievements.asJson))
      yield resp

    // GET all achievements of user for a specific game
    case GET -> Root / LongVar(rawSteamid) / AchievementsURL / IntVar(appid) :? LimitParam(limitOpt) +& OffsetParam(offsetOpt) =>
      val steamid: SteamId = SteamId(rawSteamid)
      val limit = limitOpt.getOrElse(100)
      val offset = offsetOpt.getOrElse(0)
      for
        achievements <- userAchievementsRepo.findBySteamIdAndAppId(steamid, appid, limit, offset).transact(xa)
        total<- userAchievementsRepo.countBySteamIdAndAppId(steamid, appid).transact(xa)
        resp <- Ok(Map("total" -> total.asJson, "achievements" -> achievements.asJson))
      yield resp

    // GET a specific user achievement for a game
    case GET -> Root / LongVar(rawSteamid) / AchievementsURL / IntVar(appid) / achievementKey =>
      val steamId: SteamId = SteamId(rawSteamid)
      for
        achievementOpt <- userAchievementsRepo.findOne(steamId, appid, achievementKey).transact(xa)
        resp <- achievementOpt match
          case Some(achievement) => Ok(achievement.asJson)
          case None              => NotFound()
      yield resp

    // PUT Upsert an achievement
    case req @ PUT -> Root / LongVar(rawSteamid) / AchievementsURL =>
      val steamid: SteamId = SteamId(rawSteamid)
      for
        achUpdate   <- req.as[UserAchievement]
        rowsUpdated <- userAchievementsRepo.upsert(achUpdate).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"Achievement upserted successfully for user $steamid"))
        else
          BadRequest(Map("error" -> s"Failed to upsert achievement for user $steamid"))
      yield resp
  
    // DELETE all achievements from a game
    case DELETE -> Root / LongVar(rawSteamid) / AchievementsURL / IntVar(appId) =>
      val steamid: SteamId = SteamId(rawSteamid)
      userAchievementsRepo.deleteBySteamIdAndAppId(steamid, appId).transact(xa).attempt.flatMap {
        case Right(rowsDeleted) if rowsDeleted > 0 =>
          Ok(Map("message" -> s"All achievements for game $appId removed for user $steamid ($rowsDeleted deleted)"))

        case Right(_) =>
          NotFound(Map("error" -> s"Achievements not found for game $appId and user $steamid"))

        case Left(error) =>
          InternalServerError(Map("error" -> s"Error deleting achievements: ${error.getMessage}"))
      }

    // DELETE one specific achievement
    case DELETE -> Root / LongVar(rawSteamid) / AchievementsURL / IntVar(appId) / achievementKey =>
      val steamid: SteamId = SteamId(rawSteamid)
      userAchievementsRepo.deleteByKey(steamid, appId, achievementKey).transact(xa).attempt.flatMap {
        case Right(rowsDeleted) if rowsDeleted > 0 =>
          Ok(Map("message" -> s"Achievement $achievementKey removed for game $appId and user $steamid"))

        case Right(_) =>
          NotFound(Map("error" -> s"Achievement $achievementKey not found for game $appId and user $steamid"))

        case Left(error) =>
          InternalServerError(Map("error" -> s"Error deleting achievement $achievementKey: ${error.getMessage}"))
      }