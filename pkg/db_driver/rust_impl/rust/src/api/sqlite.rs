use crate::api::db::{DataType, QueryColumn, QueryHeader, QueryRow, QueryStreamItem, QueryValue};
use crate::frb_generated::StreamSink;
use rusqlite::Connection;
use std::sync::Mutex;

/// SQLite 类型名称处理
/// 参考：SQLite 官方文档 https://www.sqlite.org/datatype3.html
/// 
/// SQLite 使用类型亲和性（Type Affinity）系统：
/// - 如果类型字符串包含 "INT" → INTEGER 亲和性
/// - 如果类型字符串包含 "CHAR", "CLOB", or "TEXT" → TEXT 亲和性
/// - 如果类型字符串包含 "BLOB" 或未指定类型 → BLOB 亲和性
/// - 如果类型字符串包含 "REAL", "FLOA", or "DOUB" → REAL 亲和性
/// - 其他情况 → NUMERIC 亲和性
/// 
/// 运行时存储类型只有 5 种：NULL, INTEGER, REAL, TEXT, BLOB
/// 参考：rusqlite::types::Type 枚举定义
fn sqlite_type_to_data_type(type_name: &str) -> DataType {
    let t = type_name.trim().to_uppercase();
    
    // 按照 SQLite 类型亲和性规则匹配
    // 优先检查 TEXT 亲和性（避免 "INTEGER" 包含 "INT" 导致误判为字符类型）

    // TEXT
    if t.contains("CHAR") || t.contains("CLOB") || t.contains("TEXT") {
        return DataType::Char;
    }
    // INTEGER
    if t.contains("INT") {
        return DataType::Number;
    }
    // REAL
    if t.contains("REAL") || t.contains("FLOA") || t.contains("DOUB") {
        return DataType::Number;
    }
    // NUMERIC
    if t.contains("NUMERIC") || t.contains("DECIMAL") || t.contains("BOOLEAN") {
        return DataType::Number;
    }
    // BLOB
    if t.contains("BLOB") {
        return DataType::Blob;
    }
    // DATE/TIME (SQLite 推荐存储为 TEXT, REAL, 或 INTEGER)
    if t.contains("DATE") || t.contains("TIME") {
        return DataType::Time;
    }
    // JSON (存储为 TEXT)
    if t.contains("JSON") {
        return DataType::Json;
    }
    // 默认：NUMERIC
    DataType::Char
}

pub struct SqliteConnection {
    conn: Mutex<Connection>,
}

impl SqliteConnection {
    pub async fn open(dsn: &str) -> Result<Self, String> {
        let conn = Connection::open(dsn).map_err(|e| e.to_string())?;
        Ok(SqliteConnection {
            conn: Mutex::new(conn),
        })
    }

    pub async fn query(
        &mut self,
        query: &str,
        sink: StreamSink<QueryStreamItem>,
    ) -> Result<(), String> {
        let query = query.trim();
        if query.is_empty() {
            let _ = sink.add(QueryStreamItem::Header(QueryHeader {
                columns: vec![],
                affected_rows: 0,
            }));
            return Ok(());
        }

        let conn = self.conn.lock().map_err(|e| e.to_string())?;

        let mut stmt = match conn.prepare(query) {
            Ok(stmt) => stmt,
            Err(e) => {
                let _ = sink.add(QueryStreamItem::Error(e.to_string()));
                return Ok(());
            }
        };

        let column_count = stmt.column_count();
        if column_count == 0 {
            drop(stmt);
            match conn.execute(query, []) {
                Ok(affected_rows) => {
                    let _ = sink.add(QueryStreamItem::Header(QueryHeader {
                        columns: vec![],
                        affected_rows: affected_rows as u64,
                    }));
                }
                Err(e) => {
                    let _ = sink.add(QueryStreamItem::Error(e.to_string()));
                }
            }
            return Ok(());
        }

        let cols = stmt.columns();
        let mut columns = Vec::with_capacity(column_count);
        for col in cols {
            let name = col.name().to_string();
            let data_type = col.decl_type()
                .map(|t| sqlite_type_to_data_type(t))
                .unwrap_or(DataType::Char);
            columns.push(QueryColumn { name, data_type });
        }

        if sink
            .add(QueryStreamItem::Header(QueryHeader {
                columns,
                affected_rows: 0,
            }))
            .is_err()
        {
            return Ok(());
        }

        let mut rows = match stmt.query([]) {
            Ok(rows) => rows,
            Err(e) => {
                let _ = sink.add(QueryStreamItem::Error(e.to_string()));
                return Ok(());
            }
        };

        while let Some(row) = rows.next().map_err(|e| e.to_string())? {
            let mut values = Vec::with_capacity(column_count);
            for i in 0..column_count {
                let value = row.get_ref(i).map_err(|e| e.to_string())?;
                let query_value = match value {
                    rusqlite::types::ValueRef::Null => QueryValue::NULL,
                    rusqlite::types::ValueRef::Integer(v) => QueryValue::Int(v),
                    rusqlite::types::ValueRef::Real(v) => QueryValue::Double(v),
                    rusqlite::types::ValueRef::Text(v) => QueryValue::Bytes(v.to_vec()),
                    rusqlite::types::ValueRef::Blob(v) => QueryValue::Bytes(v.to_vec()),
                };
                values.push(query_value);
            }

            if sink.add(QueryStreamItem::Row(QueryRow { values })).is_err() {
                return Ok(());
            }
        }

        Ok(())
    }

    pub async fn close(self) -> Result<(), String> {
        Ok(())
    }
}
