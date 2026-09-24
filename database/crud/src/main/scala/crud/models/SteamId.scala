package models

import io.circe.{Codec, Decoder, Encoder}

opaque type SteamId = Long

object SteamId:
  def apply(value: Long): SteamId = value

  extension (s: SteamId)
    def value: Long = s

  given Codec[SteamId] = Codec.from(
    Decoder[String].emap(str => str.toLongOption.toRight("Invalid SteamId")).map(apply),
    Encoder[String].contramap[SteamId](s => s.value.toString)
  )

