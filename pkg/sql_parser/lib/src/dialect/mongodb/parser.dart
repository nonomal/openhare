import 'package:sql_parser/src/lexer/token.dart';
import 'package:sql_parser/src/parser/parser.dart';

import 'keyword.dart' as mongo_kw;
import 'lexer.dart';

class MongoSplitter extends Splitter {
  MongoSplitter(String content) : super(MongoLexer(content));

  @override
  List<SQLChunk> split({String delimiter = ';', bool skipWhitespace = false, bool skipComment = false}) {
    Token? splitWhereFunc() => l.scanWhere(
          (tok) => (tok.id == TokenType.punctuation && tok.content == delimiter),
        );
    return splitWhere(splitWhereFunc, skipWhitespace: skipWhitespace, skipComment: skipComment);
  }
}

class MongoSQLDefiner extends SQLDefiner {
  static final Set<String> _read = {
    for (final k in mongo_kw.mongoReadCommands) k.toLowerCase(),
  };
  static final Set<String> _write = {
    for (final k in mongo_kw.mongoWriteCommands) k.toLowerCase(),
  };

  final String content;
  MongoSQLDefiner(this.content);

  @override
  SQLType get sqlType {
    var hitRead = false;
    var hitWrite = false;
    for (final t in MongoLexer(content).tokens()) {
      final w = t.content.toLowerCase();
      if (_write.contains(w)) hitWrite = true;
      if (_read.contains(w)) hitRead = true;
    }
    if (hitWrite) return SQLType.dml;
    if (hitRead) return SQLType.dql;
    return SQLType.other;
  }

  @override
  bool get isDangerousSQL {
    for (final t in MongoLexer(content).tokens()) {
      switch (t.content.toLowerCase()) {
        case 'dropdatabase':
        case 'drop':
        case 'remove':
          return true;
      }
    }
    return false;
  }

  @override
  bool get canLimit => false;

  @override
  bool get changeSchema => false;

  @override
  String wrapLimit(String sql, int limit) => sql;

  @override
  String trimDelimiter(String sql) {
    return MongoLexer(sql).trimEndWhere((token) {
      return token.id == TokenType.whitespace ||
          token.id == TokenType.comment ||
          (token.id == TokenType.punctuation && token.content == ';');
    });
  }
}
