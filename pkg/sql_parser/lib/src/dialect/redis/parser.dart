import 'package:sql_parser/src/lexer/token.dart';
import 'package:sql_parser/src/parser/parser.dart';

import 'keyword.dart';
import 'lexer.dart';

const Set<String> _redisDangerousCommandsUpper = {
  'FLUSHALL',
  'FLUSHDB',
  'SHUTDOWN',
  'DEBUG',
  'MODULE',
  'REPLICAOF',
  'SLAVEOF',
  'KEYS',
  'HKEYS',
  'SMEMBERS',
};

class RedisSplitter extends Splitter {
  RedisSplitter(String content) : super(RedisLexer(content));

  @override
  List<SQLChunk> split(
      {String delimiter = ";",
      bool skipWhitespace = false,
      bool skipComment = false}) {
    Token? splitWhereFunc() => l.scanWhere(
          (tok) => (tok.id == TokenType.punctuation && tok.content == delimiter),
        );
    return splitWhere(splitWhereFunc,
        skipWhitespace: skipWhitespace, skipComment: skipComment);
  }
}

String? _firstCommandUpper(String content) {
  final lexer = RedisLexer(content);
  for (final tok in lexer.tokens()) {
    if (tok.id == TokenType.whitespace || tok.id == TokenType.comment) {
      continue;
    }
    if (tok.id == TokenType.keyword || tok.id == TokenType.ident) {
      return tok.content.toUpperCase();
    }
    return null;
  }
  return null;
}

class RedisSQLDefiner extends SQLDefiner {
  final String content;
  RedisSQLDefiner(this.content);

  @override
  SQLType get sqlType {
    final cmd = _firstCommandUpper(content);
    if (cmd == null) {
      return SQLType.other;
    }
    if (redisReadCommands.contains(cmd)) {
      return SQLType.dql;
    }
    if (redisWriteCommands.contains(cmd)) {
      return SQLType.dml;
    }
    return SQLType.other;
  }

  @override
  bool get isDangerousSQL {
    final cmd = _firstCommandUpper(content);
    if (cmd == null) {
      return false;
    }
    return _redisDangerousCommandsUpper.contains(cmd);
  }

  @override
  bool get canLimit => false;

  @override
  bool get changeSchema => false;

  @override
  String wrapLimit(String sql, int limit) => sql;

  @override
  String trimDelimiter(String sql) {
    return RedisLexer(content).trimEndWhere((token) {
      return token.id == TokenType.whitespace ||
          token.id == TokenType.comment ||
          (token.id == TokenType.punctuation && token.content == ";");
    });
  }
}
