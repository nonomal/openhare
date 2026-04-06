package main

import (
	"context"
	"database/sql"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

const (
	sqliteInteger  = "INTEGER"
	sqliteInt      = "INT"
	sqliteBigInt   = "BIGINT"
	sqliteSmallInt = "SMALLINT"
	sqliteTinyInt  = "TINYINT"
	sqliteReal     = "REAL"
	sqliteDouble   = "DOUBLE"
	sqliteFloat    = "FLOAT"
	sqliteNumeric  = "NUMERIC"
	sqliteDecimal  = "DECIMAL"

	sqliteText    = "TEXT"
	sqliteChar    = "CHAR"
	sqliteVarchar = "VARCHAR"
	sqliteClob    = "CLOB"

	sqliteBlob = "BLOB"

	sqliteDate      = "DATE"
	sqliteDatetime  = "DATETIME"
	sqliteTime      = "TIME"
	sqliteTimestamp = "TIMESTAMP"

	sqliteJson = "JSON"
)

type sqliteConn struct {
	db *sql.DB
}

func (c *sqliteConn) Close() error {
	return c.db.Close()
}

func sqliteDataType(typeName string) int32 {
	t := strings.ToUpper(strings.TrimSpace(typeName))

	if strings.Contains(t, "INT") {
		return dataTypeNumber
	}
	if strings.Contains(t, "REAL") || strings.Contains(t, "FLOA") ||
		strings.Contains(t, "DOUB") || strings.Contains(t, "NUMERIC") ||
		strings.Contains(t, "DECIMAL") {
		return dataTypeNumber
	}
	if strings.Contains(t, "CHAR") || strings.Contains(t, "CLOB") ||
		strings.Contains(t, "TEXT") {
		return dataTypeChar
	}
	if strings.Contains(t, "DATE") || strings.Contains(t, "TIME") {
		return dataTypeTime
	}
	if strings.Contains(t, "BLOB") {
		return dataTypeBlob
	}
	if strings.Contains(t, "JSON") {
		return dataTypeJson
	}

	return dataTypeChar
}

func (c *sqliteConn) OpenQuery(sqlText string) (rowCursor, error) {
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
			dataType: sqliteDataType(dbType),
		})
	}

	return &sqliteCur{rows: rows, columns: columns}, nil
}

type sqliteCur struct {
	rows     *sql.Rows
	columns  []dbQueryColumn
	rowCount int64
}

func (q *sqliteCur) Close() error {
	return q.rows.Close()
}

func (q *sqliteCur) Header() *dbQueryHeader {
	return &dbQueryHeader{
		columns:      q.columns,
		affectedRows: q.rowCount,
	}
}

func (q *sqliteCur) NextRow() (*dbQueryRow, bool, error) {
	if !q.rows.Next() {
		if err := q.rows.Err(); err != nil {
			return nil, false, err
		}
		return nil, false, nil
	}
	q.rowCount++

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

func openSqliteConn(dsn string) (driverConn, error) {
	db, err := sql.Open("sqlite3", dsn)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &sqliteConn{db: db}, nil
}
