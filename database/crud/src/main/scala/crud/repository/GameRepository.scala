package repository

import models.Game
import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*
import java.time.{LocalDate, LocalDateTime}

class GameRepository:

  def findAll(limit: Int, offset: Int): ConnectionIO[List[Game]] =
    sql"""
      SELECT 
        app_id, name, short_description, genres, categories, supported_languages, 
        header_image, pc_requirements_minimum, pc_requirements_recommended, 
        processor_minimum, processor_recommended, graphics_minimum, graphics_recommended,
        ram_minimum_gb, ram_recommended_gb, storage_minimum_gb, storage_recommended_gb,
        developers, is_on_windows, is_on_mac, is_on_linux, metacritic_score, release_date, 
        price_usd, is_free, rating, total_achievements, recommendations, 
        owners_min, owners_max, positive_reviews, negative_reviews, total_reviews, 
        approval_rate, fetched_at
      FROM games
      ORDER BY app_id
      LIMIT $limit OFFSET $offset
    """.query[Game].to[List]

  def count: ConnectionIO[Long] =
    sql"SELECT COUNT(*) FROM games".query[Long].unique

  def findById(appId: Int): ConnectionIO[Option[Game]] =
    sql"""
      SELECT 
        app_id, name, short_description, genres, categories, supported_languages, 
        header_image, pc_requirements_minimum, pc_requirements_recommended, 
        processor_minimum, processor_recommended, graphics_minimum, graphics_recommended,
        ram_minimum_gb, ram_recommended_gb, storage_minimum_gb, storage_recommended_gb,
        developers, is_on_windows, is_on_mac, is_on_linux, metacritic_score, release_date, 
        price_usd, is_free, rating, total_achievements, recommendations, 
        owners_min, owners_max, positive_reviews, negative_reviews, total_reviews, 
        approval_rate, fetched_at
      FROM games
      WHERE app_id = $appId
    """.query[Game].option

  def create(game: Game): ConnectionIO[Int] =
    sql"""
      INSERT INTO games (
        app_id, name, short_description, genres, categories, supported_languages, 
        header_image, pc_requirements_minimum, pc_requirements_recommended, 
        processor_minimum, processor_recommended, graphics_minimum, graphics_recommended,
        ram_minimum_gb, ram_recommended_gb, storage_minimum_gb, storage_recommended_gb,
        developers, is_on_windows, is_on_mac, is_on_linux, metacritic_score, release_date, 
        price_usd, is_free, rating, total_achievements, recommendations, 
        owners_min, owners_max, positive_reviews, negative_reviews, total_reviews, 
        approval_rate, fetched_at
      ) VALUES (
        ${game.appId}, ${game.name}, ${game.shortDescription}, ${game.genres}, 
        ${game.categories}, ${game.supportedLanguages}, ${game.headerImage}, 
        ${game.pcRequirementsMinimum}, ${game.pcRequirementsRecommended},
        ${game.processorMinimum}, ${game.processorRecommended},
        ${game.graphicsMinimum}, ${game.graphicsRecommended},
        ${game.ramMinimumGb}, ${game.ramRecommendedGb},
        ${game.storageMinimumGb}, ${game.storageRecommendedGb},
        ${game.developers}, ${game.isOnWindows}, ${game.isOnMac}, ${game.isOnLinux}, 
        ${game.metacriticScore}, ${game.releaseDate}, ${game.priceUsd}, ${game.isFree}, 
        ${game.rating}, ${game.totalAchievements}, ${game.recommendations}, ${game.ownersMin}, 
        ${game.ownersMax}, ${game.positiveReviews}, ${game.negativeReviews}, ${game.totalReviews}, 
        ${game.approvalRate}, ${game.fetchedAt}
      )
    """.update.run

  def update(appId: Int, game: Game): ConnectionIO[Int] =
    sql"""
      UPDATE games SET
        name = ${game.name},
        short_description = ${game.shortDescription},
        genres = ${game.genres},
        categories = ${game.categories},
        supported_languages = ${game.supportedLanguages},
        header_image = ${game.headerImage},
        pc_requirements_minimum = ${game.pcRequirementsMinimum},
        pc_requirements_recommended = ${game.pcRequirementsRecommended},
        processor_minimum = ${game.processorMinimum},
        processor_recommended = ${game.processorRecommended},
        graphics_minimum = ${game.graphicsMinimum},
        graphics_recommended = ${game.graphicsRecommended},
        ram_minimum_gb = ${game.ramMinimumGb},
        ram_recommended_gb = ${game.ramRecommendedGb},
        storage_minimum_gb = ${game.storageMinimumGb},
        storage_recommended_gb = ${game.storageRecommendedGb},
        developers = ${game.developers},
        is_on_windows = ${game.isOnWindows},
        is_on_mac = ${game.isOnMac},
        is_on_linux = ${game.isOnLinux},
        metacritic_score = ${game.metacriticScore},
        release_date = ${game.releaseDate},
        price_usd = ${game.priceUsd},
        is_free = ${game.isFree},
        rating = ${game.rating},
        total_achievements = ${game.totalAchievements},
        recommendations = ${game.recommendations},
        owners_min = ${game.ownersMin},
        owners_max = ${game.ownersMax},
        positive_reviews = ${game.positiveReviews},
        negative_reviews = ${game.negativeReviews},
        total_reviews = ${game.totalReviews},
        approval_rate = ${game.approvalRate},
        fetched_at = ${game.fetchedAt}
      WHERE app_id = $appId
    """.update.run

  def delete(appId: Int): ConnectionIO[Int] =
    sql"DELETE FROM games WHERE app_id = $appId".update.run