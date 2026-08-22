package models

import java.time.{LocalDate, LocalDateTime}
import io.circe.Codec

final case class Game(
  appId: Int,
  name: String,
  shortDescription: Option[String],
  genres: Option[List[String]],
  categories: Option[List[String]],
  supportedLanguages: Option[List[String]],
  headerImage: Option[String],
  pcRequirementsMinimum: Option[String],
  pcRequirementsRecommended: Option[String],
  processor: Option[List[String]],
  graphics: Option[List[String]],
  ramRequirement: Option[List[Short]],
  storageRequirement: Option[List[Short]],
  developers: Option[String],
  isOnWindows: Option[Boolean],
  isOnMac: Option[Boolean],
  isOnLinux: Option[Boolean],
  metacriticScore: Option[Short],
  releaseDate: Option[LocalDate],
  priceUsd: Option[BigDecimal],
  isFree: Option[Boolean],
  rating: Option[String],
  totalAchievements: Option[Short],
  recommendations: Option[Int],
  ownersMin: Option[Long],
  ownersMax: Option[Long],
  positiveReviews: Option[Int],
  negativeReviews: Option[Int],
  totalReviews: Option[Int],
  approvalRate: Option[BigDecimal],
  fetchedAt: Option[LocalDateTime]
) derives Codec.AsObject
