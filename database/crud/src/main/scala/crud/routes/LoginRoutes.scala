package routes

import cats.effect.Async
import cats.syntax.all.*
import io.circe.generic.auto.*
import org.http4s.*
import org.http4s.dsl.Http4sDsl
import org.http4s.circe.CirceEntityDecoder.*
import org.http4s.circe.CirceEntityEncoder.*

case class LoginRequest(username: String, key: String)

class LoginRoutes[F[_]: Async] extends Http4sDsl[F]:

  private val validUsername: String =
    sys.env.getOrElse("CRUD_USERNAME", throw new RuntimeException("CRITICAL ERROR: 'CRUD_USERNAME' is not defined."))

  private val validKey: String =
    sys.env.getOrElse("SCALA_API_KEY", throw new RuntimeException("CRITICAL ERROR: 'SCALA_API_KEY' is not defined."))

  val routes: HttpRoutes[F] = HttpRoutes.of[F]:

    case req @ POST -> Root =>
      req.as[LoginRequest].flatMap { body =>
        if body.username == validUsername && body.key == validKey then
          val cookie = ResponseCookie(
            name = "session",
            content = validKey,
            httpOnly = true,
            sameSite = Some(SameSite.Strict),
            path = Some("/")
          )
          Ok(Map("message" -> "Login successful")).map(_.addCookie(cookie))
        else
          Unauthorized(
            org.http4s.headers.`WWW-Authenticate`(Challenge("Bearer", "api")),
            Map("error" -> "Invalid credentials")
          )
      }

    case POST -> Root / "logout" =>
      val clearCookie = ResponseCookie(
        name = "session",
        content = "",
        maxAge = Some(0),
        path = Some("/")
      )
      Ok(Map("message" -> "Logged out")).map(_.addCookie(clearCookie))