package repository

import doobie.*
import doobie.implicits.*
import doobie.postgres.implicits.*

implicit val listStringPut: Put[List[String]] = Put[Array[String]].contramap(_.toArray)
implicit val listStringGet: Get[List[String]] = Get[Array[String]].map(_.toList)

implicit val metaShortArray: Meta[Array[Short]] = 
  Meta.Advanced.array[java.lang.Short]("int2", "_int2")
    .timap(_.map(s => if (s == null) 0.toShort else s.shortValue()))(_.map(Short.box))

implicit val listShortPut: Put[List[Short]] = Put[Array[Short]].contramap(_.toArray)
implicit val listShortGet: Get[List[Short]] = Get[Array[Short]].map(_.toList)