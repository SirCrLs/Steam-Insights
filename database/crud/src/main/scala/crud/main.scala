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
import auth.ApiKeyMiddleware
import routes.{GameRoutes, UserRoutes, AchievementRoutes}
import repository.{GameRepository, UserRepository, UserGameRepository, UserAchievementRepository, AchievementRepository}
import org.http4s.HttpApp

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

      val apiRoutes = Router(
        "/games"        -> gameRoutes,
        "/users"        -> userRoutes,
        "/achievements" -> achievementRoutes
      )

      // if self hosted, base routes would be:
      // http://localhost:4000/api/games

      val protectedApiRoutes = ApiKeyMiddleware(apiRoutes)

      val allRoutes: HttpApp[IO] = Router(
        "/" -> healthRoutes(xa), // Public
        "/api" -> protectedApiRoutes // Protected
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