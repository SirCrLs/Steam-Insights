package crud

import cats.effect.{IO, IOApp, ExitCode}
import com.comcast.ip4s.*
import org.http4s.ember.server.EmberServerBuilder
import org.http4s.server.Router
import org.http4s.HttpRoutes
import org.http4s.server.middleware.{ErrorHandling, CORS}
import org.http4s.dsl.io.*
import org.http4s.implicits.*
import doobie.implicits.*
import crud.db.DatabaseConfig
import auth.ApiKeyMiddleware
import routes.{GameRoutes, UserRoutes, AchievementRoutes, QueryRoutes, LoginRoutes}
import repository.{GameRepository, UserRepository, UserGameRepository, 
UserAchievementRepository, AchievementRepository, QueryRepository}
import org.http4s.HttpApp
import cats.syntax.semigroupk.*

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
      val queryRepository = new QueryRepository()

      // Routes
      val gameRoutes = new GameRoutes[IO](gameRepository, xa).routes

      val userRoutes = new UserRoutes[IO](
        userRepository,
        userGameRepository,
        userAchievementRepository,
        xa
      ).routes

      val achievementRoutes = new AchievementRoutes[IO](achievementRepository, xa).routes

      val queryRoutes = new QueryRoutes[IO](queryRepository, xa).routes

      val loginRoutes = new LoginRoutes[IO].routes

      val allRoutes = Router(
        "/"                 -> healthRoutes(xa),
        "/login"            -> loginRoutes,
        "/api/games"        -> ApiKeyMiddleware(gameRoutes),
        "/api/users"        -> ApiKeyMiddleware(userRoutes),
        "/api/achievements" -> ApiKeyMiddleware(achievementRoutes),
        "/api/query"        -> ApiKeyMiddleware(queryRoutes)
      ).orNotFound

      val appWithErrorLogging = ErrorHandling(allRoutes)

      // CORS
      val corsApp = CORS.policy
        .withAllowOriginAll
        .withAllowMethodsAll
        .withAllowHeadersAll
        .apply(appWithErrorLogging)

      EmberServerBuilder
        .default[IO]
        .withHost(host"0.0.0.0")
        .withPort(port"4000")
        .withHttpApp(corsApp)
        .build
        .useForever
    }.as(ExitCode.Success)