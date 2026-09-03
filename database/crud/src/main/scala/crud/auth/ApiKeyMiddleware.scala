package crud.auth

import cats.data.{Kleisli, OptionT}
import cats.effect.Async
import org.http4s.*
import org.http4s.dsl.Http4sDsl
import org.http4s.headers.`WWW-Authenticate`
import org.typelevel.ci.CIString

object ApiKeyMiddleware:

  private val expectedApiKey: String = 
    sys.env.get("SCALA_API_KEY").getOrElse(
      throw new RuntimeException("CRITICAL ERROR: Environment variable 'SCALA_API_KEY' is not defined.")
    )

  private val apiKeyHeader = CIString("X-API-Key")

  def apply[F[_]: Async](routes: HttpRoutes[F]): HttpRoutes[F] =
    val dsl = new Http4sDsl[F] {}
    import dsl.*

    Kleisli { (req: Request[F]) =>
      val providedKey: Option[String] = 
        req.params.get("apiKey")
          .orElse(req.params.get("key"))
          .orElse(req.headers.get(apiKeyHeader).map(_.head.value))

      providedKey match
        case Some(key) if key == expectedApiKey =>
          routes(req)
        case _ =>
          OptionT.liftF(
            Unauthorized(
              `WWW-Authenticate`(Challenge("ApiKey", "Steam-Insights-API")),
              "Access Denied: API Key invalid or missing"
            )
          )
    }