package crud.db

import cats.effect.{Async, Resource}
import doobie.hikari.HikariTransactor
import doobie.util.ExecutionContexts
import io.github.cdimascio.dotenv.Dotenv

object DatabaseConfig:

  // Loads .env from root
  private val dotenv: Dotenv = Dotenv.configure()
    .directory("./")
    .ignoreIfMissing()
    .load()

  private def env(key: String): String =
    Option(dotenv.get(key))
      .orElse(sys.env.get(key))
      .getOrElse(throw new RuntimeException(s"Missing environment variable: $key"))

  val dbHost: String = env("DB_HOST")
  val dbPort: String = env("DB_PORT")
  val dbName: String = env("POSTGRES_DB")
  val dbUser: String = env("POSTGRES_USER")
  val dbPassword: String = env("POSTGRES_PASSWORD")

  val jdbcUrl: String = s"jdbc:postgresql://$dbHost:$dbPort/$dbName"

  def transactor[F[_]: Async]: Resource[F, HikariTransactor[F]] =
    for
      ec <- ExecutionContexts.fixedThreadPool[F](32)
      xa <- HikariTransactor.newHikariTransactor[F](
        driverClassName = "org.postgresql.Driver",
        url = jdbcUrl,
        user = dbUser,
        pass = dbPassword,
        connectEC = ec
      )
    yield xa
