use crate::frb_generated::StreamSink;
use rusqlite::{types::ValueRef, Connection};
use std::sync::Mutex;

pub enum QueryValue {
    NULL,
    Bytes(Vec<u8>),
    Int(i64),
    UInt(u64),
    Float(f32),
    Double(f64),
    DateTime(i64),
}

impl QueryValue {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn from_value_ref(value: ValueRef<'_>) -> Self {
        match value {
            ValueRef::Null => QueryValue::NULL,
            ValueRef::Integer(v) => QueryValue::Int(v),
            ValueRef::Real(v) => QueryValue::Double(v),
            ValueRef::Text(v) => QueryValue::Bytes(v.to_vec()),
            ValueRef::Blob(v) => QueryValue::Bytes(v.to_vec()),
        }
    }
}

pub enum QueryStreamItem {
    Header(QueryHeader),
    Row(QueryRow),
    Error(String),
}

pub struct QueryHeader {
    pub columns: Vec<QueryColumn>,
    pub affected_rows: u64,
}

pub struct QueryColumn {
    pub name: String,
    pub column_type: String,
}

pub struct QueryRow {
    pub values: Vec<QueryValue>,
}

pub struct ConnWrapper {
    conn: Mutex<Connection>,
}

impl ConnWrapper {
    pub async fn open(dsn: &str) -> Result<Self, String> {
        let conn = Connection::open(dsn).map_err(|e| e.to_string())?;
        Ok(ConnWrapper {
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

        let mut columns = Vec::with_capacity(column_count);
        for i in 0..column_count {
            let name = stmt.column_name(i).unwrap_or("").to_string();
            let column_type = String::new();
            columns.push(QueryColumn { name, column_type });
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
                values.push(QueryValue::from_value_ref(value));
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
