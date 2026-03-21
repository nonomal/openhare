import 'package:client/models/ai.dart';
import 'package:client/services/ai/llm_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client/services/ai/tool_query.dart';

abstract class AITool {
  /// 工具名称，用于标识工具
  String get name;

  /// 工具描述，用于 AI 理解工具的功能
  String get description;

  /// 输入参数的 JSON Schema
  Map<String, dynamic> get inputJsonSchema;
}

/// SQL 查询工具定义
///
/// Schema 供 LLM 使用；运行时执行见 [SqlExecuteQueryToolExecutor]（`tool_query.dart`）。
class QueryTool extends AITool {
  QueryTool();

  @override
  String get name => 'execute_query';

  @override
  String get description => '''
Execute a SQL query on the currently selected database connection.
Accepts a SQL statement and returns the query result (including column metadata and rows).
The result will include at most the first 100 rows.
''';

  @override
  Map<String, dynamic> get inputJsonSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'The SQL query string to execute, for example: SELECT * FROM users LIMIT 10',
      },
    },
    'required': ['query'],
  };
}

abstract class AIChatToolExecutor {
  String get name;

  /// 策略判断：是否需要二次确认（仅表达规则，不落库）。
  bool checkNeedsAwaitUserConfirm(Ref ref, AIChatId chatId);

  /// 当 [checkNeedsAwaitUserConfirm] 为 `true` 时调用：仅写入待确认状态，不执行实际操作。
  Future<void> stagePending(Ref ref, AIChatId chatId, {required void Function() onInvalidate});

  /// 当 [checkNeedsAwaitUserConfirm] 为 `false` 时调用：直接执行并更新结果。
  Future<void> run(Ref ref, AIChatId chatId, {required void Function() onInvalidate});

  /// 用户拒绝待执行的操作。
  void rejectPending(Ref ref, AIChatId chatId, AIChatMessageId messageId, void Function() onInvalidate);

  /// 用户确认后继续执行。
  Future<void> approvePending(Ref ref, AIChatId chatId, AIChatMessageId messageId, void Function() onInvalidate);
}

AIChatToolExecutor? createAIChatToolExecutor(AIChatMessageToolCall toolCall) {
  switch (toolCall.name) {
    case SqlExecuteQueryToolExecutor.toolName:
      return SqlExecuteQueryToolExecutor(query: toolCall.arguments['query'] as String);
    default:
      debugPrint('❌ [Chat] 未知的工具: ${toolCall.name}');
      return null;
  }
}

AIChatToolExecutor? createAIChatToolExecutorFromToolsModel(AIChatMessageToolCallsModel model) {
  return SqlExecuteQueryToolExecutor(query: model.toolCall.query);
}
