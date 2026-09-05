package routes

import cats.effect.Async
import cats.syntax.all.*
import io.circe.generic.auto.*
import io.circe.syntax.*
import org.http4s.*
import org.http4s.dsl.Http4sDsl
import org.http4s.circe.CirceEntityEncoder.*
import org.http4s.circe.CirceEntityDecoder.*
import doobie.implicits.*
import doobie.util.transactor.Transactor

import repository.QueryRepository

case class QueryRequest(sql: String)

class QueryRoutes[F[_]: Async](queryRepository: QueryRepository, xa: Transactor[F]) extends Http4sDsl[F]:

  private val selectOnlyPattern = "(?is)^\\s*(--.*\\R|\\s)*select\\b".r

  private def isSelectOnly(sql: String): Boolean =
    selectOnlyPattern.pattern.matcher(sql.trim).find()

  private def isSingleStatement(sql: String): Boolean =
    val trimmed = sql.trim
    val withoutTrailingSemicolon =
      if trimmed.endsWith(";") then trimmed.dropRight(1) else trimmed
    !withoutTrailingSemicolon.contains(";")

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:

    case req @ POST -> Root =>
      for
        body <- req.as[QueryRequest]
        resp <-
          if !isSelectOnly(body.sql) then
            BadRequest(Map("error" -> "Only SELECT statements are allowed"))
          else if !isSingleStatement(body.sql) then
            BadRequest(Map("error" -> "Only a single statement is allowed (no ';' separators)"))
          else
            queryRepository.runSelect(body.sql).transact(xa).attempt.flatMap {
              case Right(result) => Ok(result.asJson)
              case Left(e)        => BadRequest(Map("error" -> e.getMessage))
            }
      yield resp