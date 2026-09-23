package repository

import doobie.*
import doobie.implicits.*
import doobie.free.connection.raw
import java.sql.ResultSet

case class QueryResult(columns: List[String], rows: List[List[Option[String]]], rowCount: Int)

class QueryRepository:

  def runSelect(query: String): ConnectionIO[List[Map[String, Option[String]]]] =
    raw { conn =>
      val statement = conn.createStatement()
      try
        val rs: ResultSet = statement.executeQuery(query)
        val meta = rs.getMetaData
        val colCount = meta.getColumnCount
        val columns = (1 to colCount).map(meta.getColumnLabel).toList

        val rows = scala.collection.mutable.ListBuffer[Map[String, Option[String]]]()
        while rs.next() do
          val rowMap = columns.zipWithIndex.map { case (colName, idx) =>
            colName -> Option(rs.getString(idx + 1))
          }.toMap
          rows += rowMap

        rows.toList
      finally
        statement.close()
    }