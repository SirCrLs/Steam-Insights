FROM sbtscala/scala-sbt:eclipse-temurin-17.0.19_10_1.12.15_3.3.8 AS builder

WORKDIR /app
COPY build.sbt .
COPY project ./project
COPY src ./src

RUN sbt assembly

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=builder /app/target/scala-3.3.6/steam-insights-crud-assembly-*.jar app.jar
EXPOSE 4000
CMD ["java", "-jar", "app.jar"]