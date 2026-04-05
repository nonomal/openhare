package main

import (
	"context"
	"time"

	go_ora "github.com/sijms/go-ora/v2"
)

// Oracle 类型名称常量（来源：github.com/sijms/go-ora/v2）
// 参考：go_ora 驱动源码中的 TNSType 枚举定义
const (
	// Number types
	oraNUMBER   = "NUMBER"
	oraBInteger = "BInteger"
	oraFLOAT    = "FLOAT"
	oraUINT     = "UINT"
	oraIBFloat  = "IBFloat"
	oraIBDouble = "IBDouble"
	oraBFloat   = "BFloat"
	oraBDouble  = "BDouble"

	// Character types
	oraNCHAR          = "NCHAR"
	oraVARCHAR        = "VARCHAR"
	oraLONG           = "LONG"
	oraLongVarChar    = "LongVarChar"
	oraCHAR           = "CHAR"
	oraCHARZ          = "CHARZ"
	oraOCIString      = "OCIString"
	oraOCIClobLocator = "OCIClobLocator"

	// Date/Time types
	oraDATE             = "DATE"
	oraOCIDate          = "OCIDate"
	oraTimeStampDTY     = "TimeStampDTY"
	oraTimeStampTZ_DTY  = "TimeStampTZ_DTY"
	oraIntervalYM_DTY   = "IntervalYM_DTY"
	oraIntervalDS_DTY   = "IntervalDS_DTY"
	oraTimeTZ           = "TimeTZ"
	oraTIMESTAMP        = "TIMESTAMP"
	oraTIMESTAMPTZ      = "TIMESTAMPTZ"
	oraIntervalYM       = "IntervalYM"
	oraIntervalDS       = "IntervalDS"
	oraTimeStampLTZ_DTY = "TimeStampLTZ_DTY"
	oraTimeStampeLTZ    = "TimeStampeLTZ"

	// Binary types
	oraRAW            = "RAW"
	oraLongRaw        = "LongRaw"
	oraVarRaw         = "VarRaw"
	oraLongVarRaw     = "LongVarRaw"
	oraOCIBlobLocator = "OCIBlobLocator"
	oraOCIFileLocator = "OCIFileLocator"

	// JSON/XML types
	oraXMLType    = "XMLType"
	oraOCIXMLType = "OCIXMLType"

	// Special types
	oraREFCURSOR = "REFCURSOR"
	oraRESULTSET = "RESULTSET"
)

type oraConn struct {
	conn *go_ora.Connection
}

func (c *oraConn) Close() error { return c.conn.Close() }

func oracleDataType(typeName string) int32 {
	switch typeName {
	// Number types
	case oraNUMBER, oraBInteger, oraFLOAT, oraUINT, oraIBFloat, oraIBDouble, oraBFloat, oraBDouble:
		return dataTypeNumber

	// Character types
	case oraNCHAR, oraVARCHAR, oraLONG, oraLongVarChar, oraCHAR, oraCHARZ, oraOCIString, oraOCIClobLocator:
		return dataTypeChar

	// Date/Time types
	case oraDATE, oraOCIDate, oraTimeStampDTY, oraTimeStampTZ_DTY, oraIntervalYM_DTY,
		oraIntervalDS_DTY, oraTimeTZ, oraTIMESTAMP, oraTIMESTAMPTZ, oraIntervalYM,
		oraIntervalDS, oraTimeStampLTZ_DTY, oraTimeStampeLTZ:
		return dataTypeTime

	// Binary types
	case oraRAW, oraLongRaw, oraVarRaw, oraLongVarRaw, oraOCIBlobLocator, oraOCIFileLocator:
		return dataTypeBlob

	// JSON/XML types
	case oraXMLType, oraOCIXMLType:
		return dataTypeJson

	// Special types
	case oraREFCURSOR, oraRESULTSET:
		return dataTypeDataSet

	default:
		return dataTypeChar
	}
}

func (c *oraConn) OpenQuery(sql string) (rowCursor, error) {
	stmt := go_ora.NewStmt(sql, c.conn)
	rows, err := stmt.Query_(nil)
	if err != nil {
		stmt.Close()
		return nil, err
	}
	names := rows.Columns()
	columns := make([]dbQueryColumn, 0, len(names))
	for i, name := range names {
		typeName := rows.ColumnTypeDatabaseTypeName(i)
		columns = append(columns, dbQueryColumn{
			name:     name,
			dataType: oracleDataType(typeName),
		})
	}
	return &oraCur{
		stmt: stmt, rows: rows, columns: columns,
	}, nil
}

type oraCur struct {
	stmt    *go_ora.Stmt
	rows    *go_ora.DataSet
	columns []dbQueryColumn
}

func (q *oraCur) Close() error {
	var err error
	if q.rows != nil {
		err = q.rows.Close()
	}
	if q.stmt != nil {
		if e := q.stmt.Close(); e != nil && err == nil {
			err = e
		}
	}
	return err
}

func (q *oraCur) Header() *dbQueryHeader {
	return &dbQueryHeader{columns: q.columns}
}

func (q *oraCur) NextRow() (*dbQueryRow, bool, error) {
	if !q.rows.Next_() {
		if err := q.rows.Err(); err != nil {
			return nil, false, err
		}
		return nil, false, nil
	}

	raw := make([]any, len(q.columns))
	scanArgs := make([]any, len(q.columns))
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

func openOracleConn(dsn string) (driverConn, error) {
	conn, err := go_ora.NewConnection(dsn, nil)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := conn.OpenWithContext(ctx); err != nil {
		return nil, err
	}
	if err := conn.Ping(ctx); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return &oraConn{conn: conn}, nil
}
