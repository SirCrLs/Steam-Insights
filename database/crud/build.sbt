ThisBuild / version := "0.1.0"
ThisBuild / scalaVersion := "3.3.6"

val http4sVersion = "0.23.27"
val doobieVersion = "1.0.0-RC5"

lazy val root = (project in file("."))
    .settings(
    name := "steam-insights-crud",
    libraryDependencies ++= Seq(
        "org.http4s" %% "http4s-ember-server" % http4sVersion,
        "org.http4s" %% "http4s-dsl" % http4sVersion,
        "org.http4s" %% "http4s-circe" % http4sVersion,
        "io.circe" %% "circe-generic" % "0.14.10",
        "org.tpolecat" %% "doobie-core" % doobieVersion,
        "org.tpolecat" %% "doobie-postgres" % doobieVersion,
        "org.tpolecat" %% "doobie-hikari" % doobieVersion,
        "ch.qos.logback" % "logback-classic" % "1.5.12"
    )
)