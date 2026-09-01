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

import models.Achievement
import repository.AchievementRepository

class AchievementRoutes[F[_]: Async](achRepository: AchievementRepository, xa : Transactor[F]) extends Http4sDsl[F]:

  // decode/code JSON 
  implicit val achievementEntityEncoder: EntityEncoder[F, Achievement] = jsonEncoderOf[F, Achievement]
  implicit val achievementListEntityEncoder: EntityEncoder[F, List[Achievement]] = jsonEncoderOf[F, List[Achievement]]
  implicit val achievementEntityDecoder: EntityDecoder[F, Achievement] = jsonOf[F, Achievement]

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:
    //GET all achievements
    case GET -> Root =>
      for
        achievements <- achRepository.findAll.transact(xa)
        resp <- Ok(achievements)
      yield resp

    //GET achievements by appid
    case GET -> Root / IntVar(id) =>
      for
        maybeAchievement <- achRepository.findById(id).transact(xa)
        resp <- Ok(maybeAchievement)
      yield resp

    // POST create achievement
    case req @ POST -> Root =>
      for
        newAchievement <- req.as[Achievement]
        rowsInserted <- achRepository.create(newAchievement).transact(xa)
        resp <- if rowsInserted > 0 then
          Created(Map("message" -> "Success : ", "count" -> rowsInserted.toString))
        else
          BadRequest(Map("error" -> "Create failed"))
      yield resp

    // PUT update an achievement
    case req @ PUT -> Root / key / IntVar(appid) =>
      for
        achUpdate <- req.as[Achievement]
        rowsUpdated <- achRepository.update(achUpdate, key, appid).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"Achievement $key updated."))
        else
          NotFound(Map("error" -> s"Update failed: achievement $key does not exist"))
      yield resp

    // DELETE ach by id
    case DELETE -> Root / key / IntVar(appid) =>
      for
        rowsDeleted <- achRepository.delete(appid,key).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"Delete failed: achievement $key does not exist"))
      yield resp