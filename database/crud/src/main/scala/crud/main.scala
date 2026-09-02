package crud

import cats.effect.{IO, IOApp, ExitCode}
import com.comcast.ip4s.*
import org.http4s.ember.server.EmberServerBuilder
import org.http4s.server.Router
import org.http4s.HttpRoutes
import org.http4s.server.middleware.ErrorHandling
import org.http4s.dsl.io.*
import org.http4s.implicits.*
import doobie.implicits.*
import crud.db.DatabaseConfig
import routes.{GameRoutes, UserRoutes, AchievementRoutes}
import repository.{GameRepository, UserRepository, UserGameRepository, UserAchievementRepository, AchievementRepository}

object Main extends IOApp:

  private def healthRoutes(xa: doobie.Transactor[IO]): HttpRoutes[IO] =
    HttpRoutes.of[IO] {
      case GET -> Root / "health" =>
        Ok("CRUD service is running")

      case GET -> Root / "health" / "db" =>
        sql"SELECT 1".query[Int].unique.transact(xa)
          .attempt
          .flatMap {
            case Right(_) => Ok("Database connection OK")
            case Left(e)  => InternalServerError(s"Database connection failed: ${e.getMessage}")
          }
    }

  def run(args: List[String]): IO[ExitCode] =
    DatabaseConfig.transactor[IO].use { xa =>
      // Repos
      val gameRepository = new GameRepository()
      val userRepository = new UserRepository()
      val userGameRepository = new UserGameRepository()
      val userAchievementRepository = new UserAchievementRepository()
      val achievementRepository = new AchievementRepository()

      // Routes
      val gameRoutes = new GameRoutes[IO](gameRepository, xa).routes

      val userRoutes = new UserRoutes[IO](
        userRepository,
        userGameRepository,
        userAchievementRepository,
        xa
      ).routes

      val achievementRoutes = new AchievementRoutes[IO](achievementRepository, xa).routes

      val allRoutes = Router(
        "/" -> healthRoutes(xa),
        "/api/games" -> gameRoutes,
        "/api/users" -> userRoutes,
        "/api/achievements" -> achievementRoutes
      ).orNotFound

      val appWithErrorLogging = ErrorHandling(allRoutes)

      EmberServerBuilder
        .default[IO]
        .withHost(host"0.0.0.0")
        .withPort(port"4000")
        .withHttpApp(allRoutes)
        .build
        .useForever
    }.as(ExitCode.Success)