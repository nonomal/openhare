import 'package:collection/collection.dart';
import 'package:sql_parser/parser.dart' as sp;
import 'package:go_impl/go_impl.dart' as impl;

import 'db_driver_conn_meta.dart';
import 'db_driver_interface.dart';
import 'db_driver_metadata.dart';

class SqliteQueryValue extends BaseQueryValue {
  final impl.DbQueryValue _value;

  SqliteQueryValue(this._value);

  @override
  String? getString() => _value.asString();

  @override
  List<int> getBytes() => _value.asBytes();
}

class SqliteQueryColumn extends BaseQueryColumn {
  final impl.DbQueryColumn _column;

  SqliteQueryColumn(this._column);

  @override
  String get name => _column.name;

  @override
  DataType dataType() {
    return switch (_column.dataType) {
      impl.DbDataType.number => DataType.number,
      impl.DbDataType.char => DataType.char,
      impl.DbDataType.time => DataType.time,
      impl.DbDataType.blob => DataType.blob,
      impl.DbDataType.json => DataType.json,
      impl.DbDataType.dataSet => DataType.dataSet,
    };
  }
}

class SQLiteConnection extends BaseConnection {
  final impl.ImplConnection _conn;

  SQLiteConnection(this._conn);

  @override
  sp.SQLDefiner parser(String sql) => sp.parser(sp.DialectType.sqlite, sql);

  static Future<BaseConnection> open(
      {required ConnectValue meta, String? schema}) async {
    var dsn = meta.getDbFile();
    if (dsn.startsWith("file://")) {
      dsn = Uri.parse(dsn).toFilePath();
    }
    final conn =
        await impl.ImplConnection.openSqlite(dsn.isEmpty ? ":memory:" : dsn);
    final sqliteConn = SQLiteConnection(conn);
    return sqliteConn;
  }

  @override
  Future<void> close() async {
    await _conn.close();
  }

  @override
  Future<void> ping() async {
    await query("SELECT 1");
  }

  @override
  Future<void> killQuery() async {
    return;
  }

  @override
  Stream<BaseQueryStreamItem> queryStreamInternal(String sql) async* {
    List<BaseQueryColumn>? columns;

    await for (final item in _conn.streamQuery(sql)) {
      switch (item) {
        case impl.DbQueryHeader():
          columns = item.columns
              .map<BaseQueryColumn>((c) => SqliteQueryColumn(c))
              .toList(growable: false);
          yield QueryStreamItemHeader(
            columns: columns,
            affectedRows: item.affectedRows,
          );
        case impl.DbQueryRow():
          final currentColumns = columns;
          if (currentColumns == null) {
            throw StateError('No header received before row');
          }
          yield QueryStreamItemRow(
            row: QueryResultRow(
              currentColumns,
              item.values
                  .map<BaseQueryValue>((v) => SqliteQueryValue(v))
                  .toList(growable: false),
            ),
          );
      }
    }
  }

  @override
  Future<String> version() async {
    final results = await query("SELECT sqlite_version() AS version");
    return results.rows.first.getString("version") ?? "";
  }

  @override
  Future<List<MetaDataNode>> metadata() async {
    final results = await query("""SELECT
    'main' AS TABLE_SCHEMA,
    m.name AS TABLE_NAME,
    p.name AS COLUMN_NAME,
    p.type AS DATA_TYPE
FROM
    sqlite_master AS m
JOIN
    pragma_table_info(m.name) AS p
WHERE
    m.type IN ('table', 'view')
    AND m.name NOT LIKE 'sqlite_%'
ORDER BY
    m.name,
    p.cid;""");

    final rows = results.rows;
    final schemaNodes = <MetaDataNode>[];
    final schemaRows =
        rows.groupListsBy((result) => result.getString("TABLE_SCHEMA")!);

    for (final schema in schemaRows.keys) {
      final schemaNode = MetaDataNode(MetaType.schema, schema);
      schemaNodes.add(schemaNode);

      final tableNodes = <MetaDataNode>[];
      final tableRows = schemaRows[schema]!
          .groupListsBy((result) => result.getString("TABLE_NAME")!);
      for (final table in tableRows.keys) {
        final tableNode = MetaDataNode(MetaType.table, table);
        tableNodes.add(tableNode);

        final columnRows = tableRows[table]!;
        final columnNodes = columnRows
            .map((result) =>
                MetaDataNode(MetaType.column, result.getString("COLUMN_NAME")!)
                  ..withProp(
                    MetaDataPropType.dataType,
                    _getDataType(result.getString("DATA_TYPE") ?? ""),
                  ))
            .toList();
        tableNode.items = columnNodes;
      }

      schemaNode.items = tableNodes;
    }

    return schemaNodes;
  }

  static DataType _getDataType(String dataType) {
    final t = dataType.toUpperCase().trim();
    if (t.contains("INT") ||
        t.contains("REAL") ||
        t.contains("FLOA") ||
        t.contains("DOUB") ||
        t.contains("NUMERIC") ||
        t.contains("DECIMAL")) {
      return DataType.number;
    }
    if (t.contains("CHAR") || t.contains("CLOB") || t.contains("TEXT")) {
      return DataType.char;
    }
    if (t.contains("DATE") || t.contains("TIME")) {
      return DataType.time;
    }
    if (t.contains("BLOB")) {
      return DataType.blob;
    }
    if (t.contains("JSON")) {
      return DataType.json;
    }
    return DataType.char;
  }

  @override
  Future<List<String>> schemas() async {
    return ["main"];
  }

  @override
  Future<void> setCurrentSchema(String schema) async {
    onSchemaChanged("main");
  }

  @override
  Future<String?> getCurrentSchema() async {
    return "main";
  }
}
