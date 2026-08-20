package crud

import cats.effect.{IO, IOApp, ExitCode}
import com.comcast.ip4s.*
import org.http4s.ember.server.EmberServerBuilder
import org.http4s.HttpRoutes
import org.http4s.dsl.io.*
import org.http4s.implicits.*
import doobie.implicits.*
import crud.db.DatabaseConfig

object Main extends IOApp:

  private def healthRoutes(xa: doobie.Transactor[IO]): HttpRoutes[IO] = HttpRoutes.of[IO] {
      case GET -> Root / "health" => Ok("CRUD service is running")

      case GET -> Root / "health" / "db" =>
        sql"SELECT 1".query[Int].unique.transact(xa).attempt.flatMap {
            case Right(_) => Ok("Database connection OK")
            case Left(e)  => InternalServerError(s"Database connection failed: ${e.getMessage}")
          }
    }

  def run(args: List[String]): IO[ExitCode] =
    DatabaseConfig.transactor[IO].use { 
      xa => val app = healthRoutes(xa).orNotFound

      EmberServerBuilder
        .default[IO]
        .withHost(host"0.0.0.0")
        .withPort(port"4000")
        .withHttpApp(app)
        .build
        .useForever
    }.as(ExitCode.Success)