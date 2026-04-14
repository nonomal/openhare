import 'package:sql_parser/src/dialect/mongodb/keyword.dart' as mongo_kw;
import 'package:sql_parser/src/lexer/lexer.dart';
import 'package:sql_parser/src/lexer/token_builder.dart';

/// mongosh / gomongo shell 词法（含关键字高亮）。
class MongoLexer extends Lexer {
  static final TokenBuilder _builder = TokenRooter(<TokenBuilder>[
    EOFTokenBuilder(),
    SpaceTokenBuilder(),
    KeyWordTokenBuilder(mongo_kw.keywords),
    SingleQValueTokenBuilder(),
    DoubleQValueTokenBuilder(),
    BackQValueTokenBuilder(),
    NumberTokenBuilder(),
    CommentBuilder(),
    PunctuationTokenBuilder(),
  ]);

  MongoLexer(String content) : super(_builder, content);
}
