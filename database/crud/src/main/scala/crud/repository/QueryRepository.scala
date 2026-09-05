package repository

import doobie.*
import doobie.implicits.*
import doobie.free.connection.raw
import java.sql.ResultSet

case class QueryResult(columns: List[String], rows: List[List[Option[String]]], rowCount: Int)

class QueryRepository:

  def runSelect(query: String): ConnectionIO[QueryResult] =
    raw { conn =>
      val statement = conn.createStatement()
      try
        val rs: ResultSet = statement.executeQuery(query)
        val meta = rs.getMetaData
        val colCount = meta.getColumnCount
        val columns = (1 to colCount).map(meta.getColumnLabel).toList

        val rows = scala.collection.mutable.ListBuffer[List[Option[String]]]()
        while rs.next() do
          val row = (1 to colCount).map(i => Option(rs.getString(i))).toList
          rows += row

        QueryResult(columns, rows.toList, rows.size)
      finally
        statement.close()
    }