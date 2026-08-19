FROM sbtscala/scala-sbt:eclipse-temurin-21.0.2_13_1.10.2_3.3.6 AS builder

WORKDIR /app
COPY build.sbt .
COPY project ./project
COPY src ./src

RUN sbt assembly

FROM eclipse-temurin:21-jre-jammy

WORKDIR /app
COPY --from=builder /app/target/scala-3.3.6/steam-insights-crud-web-assembly-*.jar app.jar

EXPOSE 4000

CMD ["java", "-jar", "app.jar"]