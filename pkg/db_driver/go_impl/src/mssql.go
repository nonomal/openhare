package main

import (
	"context"
	"database/sql"
	"time"

	_ "github.com/microsoft/go-mssqldb"
)

// MSSQL 类型名称常量（来源：github.com/microsoft/go-mssqldb）
// 参考：MSSQL 官方文档和 go-mssqldb 驱动实现
const (
	// Number types
	// https://learn.microsoft.com/en-us/sql/t-sql/data-types/numeric-types
	mssqlInt        = "int"
	mssqlBigint     = "bigint"
	mssqlSmallint   = "smallint"
	mssqlTinyint    = "tinyint"
	mssqlDecimal    = "decimal"
	mssqlNumeric    = "numeric"
	mssqlMoney      = "money"
	mssqlSmallmoney = "smallmoney"
	mssqlFloat      = "float"
	mssqlReal       = "real"

	// Character types
	// https://learn.microsoft.com/en-us/sql/t-sql/data-types/char-and-varchar-transact-sql
	mssqlChar             = "char"
	mssqlVarchar          = "varchar"
	mssqlText             = "text"
	mssqlNchar            = "nchar"
	mssqlNvarchar         = "nvarchar"
	mssqlNtext            = "ntext"
	mssqlUniqueidentifier = "uniqueidentifier"

	// Date/Time types
	// https://learn.microsoft.com/en-us/sql/t-sql/data-types/date-and-time-types
	mssqlDate           = "date"
	mssqlTime           = "time"
	mssqlDatetime       = "datetime"
	mssqlDatetime2      = "datetime2"
	mssqlSmalldatetime  = "smalldatetime"
	mssqlDatetimeoffset = "datetimeoffset"

	// Binary types
	// https://learn.microsoft.com/en-us/sql/t-sql/data-types/binary-and-varbinary-transact-sql
	mssqlBinary    = "binary"
	mssqlVarbinary = "varbinary"
	mssqlImage     = "image"

	// Special types
	mssqlBit = "bit"
	mssqlXml = "xml"
)

type mssqlConn struct {
	db *sql.DB
}

func (c *mssqlConn) Close() error {
	return c.db.Close()
}

func mssqlDataType(typeName string) int32 {
	// MSSQL 类型名称精确匹配
	switch typeName {
	// Number types
	case mssqlInt, mssqlBigint, mssqlSmallint, mssqlTinyint,
		mssqlDecimal, mssqlNumeric,
		mssqlMoney, mssqlSmallmoney,
		mssqlFloat, mssqlReal:
		return dataTypeNumber

	// Character types
	case mssqlChar, mssqlVarchar, mssqlText,
		mssqlNchar, mssqlNvarchar, mssqlNtext,
		mssqlUniqueidentifier:
		return dataTypeChar

	// Date/Time types
	case mssqlDate, mssqlTime,
		mssqlDatetime, mssqlDatetime2, mssqlSmalldatetime, mssqlDatetimeoffset:
		return dataTypeTime

	// Binary types
	case mssqlBinary, mssqlVarbinary, mssqlImage:
		return dataTypeBlob

	// Special types
	case mssqlBit:
		return dataTypeDataSet
	case mssqlXml:
		return dataTypeJson

	default:
		return dataTypeChar
	}
}

func (c *mssqlConn) OpenQuery(sqlText string) (rowCursor, error) {
	rows, err := c.db.QueryContext(context.Background(), sqlText)
	if err != nil {
		return nil, err
	}

	names, err := rows.Columns()
	if err != nil {
		_ = rows.Close()
		return nil, err
	}
	colTypes, err := rows.ColumnTypes()
	if err != nil {
		_ = rows.Close()
		return nil, err
	}

	columns := make([]dbQueryColumn, 0, len(names))
	for i, name := range names {
		dbType := ""
		if i < len(colTypes) && colTypes[i] != nil {
			dbType = colTypes[i].DatabaseTypeName()
		}
		columns = append(columns, dbQueryColumn{
			name:     name,
			dataType: mssqlDataType(dbType),
		})
	}

	return &mssqlCur{rows: rows, columns: columns}, nil
}

type mssqlCur struct {
	rows    *sql.Rows
	columns []dbQueryColumn
}

func (q *mssqlCur) Close() error {
	return q.rows.Close()
}

func (q *mssqlCur) Header() *dbQueryHeader {
	return &dbQueryHeader{columns: q.columns}
}

func (q *mssqlCur) NextRow() (*dbQueryRow, bool, error) {
	if !q.rows.Next() {
		if err := q.rows.Err(); err != nil {
			return nil, false, err
		}
		return nil, false, nil
	}

	n := len(q.columns)
	raw := make([]any, n)
	scanArgs := make([]any, n)
	for i := range raw {
		scanArgs[i] = &raw[i]
	}
	if err := q.rows.Scan(scanArgs...); err != nil {
		return nil, false, err
	}

	values := make([]dbQueryValue, 0, len(raw))
	for _, value := range raw {
		values = append(values, buildQueryValue(value))
	}
	return &dbQueryRow{values: values}, true, nil
}

func openMssqlConn(dsn string) (driverConn, error) {
	db, err := sql.Open("sqlserver", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(4)
	db.SetConnMaxLifetime(0)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &mssqlConn{db: db}, nil
}
