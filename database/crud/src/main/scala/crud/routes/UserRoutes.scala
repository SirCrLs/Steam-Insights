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

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:
    //GET all users
    case GET -> Root =>
      for
        users <- userRepository.findAll.transact(xa)
        resp <- Ok(users)
      yield resp

    //GET user by steamid
    case GET -> Root / LongVar(steamid) =>
      for
        maybeUser <- userRepository.findById(steamid).transact(xa)
        resp <- maybeUser match
          case Some(user) => Ok(user)
          case None => NotFound(s"Game not found: ID $steamid")
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