import 'package:sql_parser/src/lexer/lexer.dart';
import 'package:sql_parser/src/lexer/token_builder.dart';

import 'keyword.dart';

class RedisLexer extends Lexer {
  static final TokenBuilder _builder = TokenRooter(<TokenBuilder>[
    EOFTokenBuilder(),
    SpaceTokenBuilder(),
    KeyWordTokenBuilder(keywords),
    SingleQValueTokenBuilder(),
    DoubleQValueTokenBuilder(),
    NumberTokenBuilder(),
    CommentBuilder(),
    PunctuationTokenBuilder(),
  ]);

  RedisLexer(String content) : super(_builder, content);
}
