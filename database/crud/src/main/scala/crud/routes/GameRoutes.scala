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

import models.Game
import repository.GameRepository

class GameRoutes[F[_]: Async](gameRepository: GameRepository, xa : Transactor[F]) extends Http4sDsl[F]:

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:

    // GET all games
    case GET -> Root => 
      for
        games <- gameRepository.findAll.transact(xa)
        resp <- Ok(games)
      yield resp

    // GET games by id
    case GET -> Root / IntVar(id) =>
      for
        maybeGame <- gameRepository.findById(id).transact(xa) 
        resp <- maybeGame match
          case Some(game) => Ok(game)
          case None => NotFound(s"Game not found: ID $id")
      yield resp

    // POST create game
    case req @ POST -> Root =>
      for
        newGame <- req.as[Game]
        rowsInserted <- gameRepository.create(newGame).transact(xa)
        resp <- if rowsInserted > 0 then
          Created(Map("message" -> "Success : ", "count" -> rowsInserted.toString))
        else
          BadRequest(Map("error" -> "Create failed"))
      yield resp

    // PUT update a game
    case req @ PUT -> Root / IntVar(id) =>
      for
        gameUpdate <- req.as[Game]
        rowsUpdated <- gameRepository.update(id, gameUpdate).transact(xa)
        resp <- if rowsUpdated > 0 then
          Ok(Map("message" -> s"Game $id updated."))
        else
          NotFound(Map("error" -> s"Update failed: game $id does not exist"))
      yield resp

    // DELETE game by id
    case DELETE -> Root / IntVar(id) =>
      for
        rowsDeleted <- gameRepository.delete(id).transact(xa)
        resp <- if rowsDeleted > 0 then
          NoContent()
        else
          NotFound(Map("error" -> s"Delete failed: game $id does not exist"))
      yield resp
