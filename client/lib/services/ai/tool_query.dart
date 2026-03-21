import 'package:client/models/ai.dart';
import 'package:client/models/sessions.dart';
import 'package:client/repositories/ai/chat.dart';
import 'package:client/services/ai/tool.dart';
import 'package:client/services/instances/instances.dart';
import 'package:client/services/sessions/session_conn.dart';
import 'package:client/services/sessions/sessions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sql_parser/parser.dart';

/// LLM `execute_query`：策略判断、待确认、执行与续跑。
final class SqlExecuteQueryToolExecutor implements AIChatToolExecutor {
  const SqlExecuteQueryToolExecutor({required this.query});

  static const String toolName = 'execute_query';

  final String query;

  @override
  String get name => toolName;

  @override
  bool checkNeedsAwaitUserConfirm(Ref ref, AIChatId chatId) {
    if (query.isEmpty) {
      return false;
    }
    final sessionId = SessionId(value: chatId.value);
    final session = ref.read(sessionsServicesProvider.notifier).getSession(sessionId);
    DialectType dialect = DialectType.mysql;
    if (session?.instanceId != null) {
      final inst = ref.read(instancesServicesProvider.notifier).getInstanceById(session!.instanceId!);
      dialect = inst?.dbType.dialectType ?? DialectType.mysql;
    }

    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    try {
      final chunks = splitSQL(dialect, trimmed, skipWhitespace: true, skipComment: true);
      final parts = chunks.map((c) => c.content.trim()).where((c) => c.isNotEmpty).toList();
      final statements = parts.isEmpty ? <String>[trimmed] : parts;
      for (final s in statements) {
        final sd = parser(dialect, s);
        if (sd.sqlType != SQLType.dql || sd.isDangerousSQL) return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> stagePending(Ref ref, AIChatId chatId, {required void Function() onInvalidate}) async {
    if (query.isEmpty) {
      throw Exception('query 参数不能为空');
    }

    final msg = AIChatMessageToolCallsModel(
      id: AIChatMessageId.generate(),
      toolCall: AIChatMessageToolCallQueryModel(
        query: query,
        execState: AIChatToolQueryState.awaitingUserConfirm,
      ),
    );
    ref.read(aiChatRepoProvider).addMessage(chatId, AIChatMessageItem.toolsResult(msg));
    onInvalidate();
  }

  @override
  Future<void> run(Ref ref, AIChatId chatId, {required void Function() onInvalidate}) async {
    if (query.isEmpty) {
      throw Exception('query 参数不能为空');
    }

    // 更新状态为running
    final msg = AIChatMessageToolCallsModel(
      id: AIChatMessageId.generate(),
      toolCall: AIChatMessageToolCallQueryModel(
        query: query,
        execState: AIChatToolQueryState.running,
      ),
    );
    ref.read(aiChatRepoProvider).addMessage(chatId, AIChatMessageItem.toolsResult(msg));
    onInvalidate();

    // 执行查询
    final sessionId = SessionId(value: chatId.value);
    try {
      final sessionModel = ref.read(sessionsServicesProvider.notifier).getSession(sessionId);
      if (sessionModel == null || sessionModel.connId == null) {
        throw Exception('会话未连接');
      }
      final startTime = DateTime.now();
      final connServices = ref.read(sessionConnsServicesProvider.notifier);
      final queryResult = await connServices.query(sessionModel.connId!, query);
      final executeTime = DateTime.now().difference(startTime);

      final done = msg.copyWith(
        toolCall: queryResult == null
            ? AIChatMessageToolCallQueryModel(
                query: query,
                errorMessage: '查询返回空结果', // todo: 对空结果的处理
                executeTime: executeTime,
                execState: AIChatToolQueryState.failed,
              )
            : AIChatMessageToolCallQueryModel(
                query: query,
                queryResult: queryResult,
                executeTime: executeTime,
                execState: AIChatToolQueryState.finished,
              ),
      );
      ref.read(aiChatRepoProvider).updateMessageById(chatId, msg.id, AIChatMessageItem.toolsResult(done));
      onInvalidate();
    } catch (e) {
      final err = msg.copyWith(
        toolCall: AIChatMessageToolCallQueryModel(
          query: query,
          errorMessage: e.toString(),
          execState: AIChatToolQueryState.failed,
        ),
      );
      ref.read(aiChatRepoProvider).updateMessageById(chatId, msg.id, AIChatMessageItem.toolsResult(err));
      onInvalidate();
    }
  }

  @override
  void rejectPending(Ref ref, AIChatId chatId, AIChatMessageId messageId, void Function() onInvalidate) {
    final found = ref
        .read(aiChatRepoProvider)
        .getMessageById(chatId, messageId)
        ?.maybeWhen(
          toolsResult: (t) => t,
          orElse: () => null,
        );
    if (found == null || !found.toolCall.isAwaitingUserConfirm) return;

    final rejected = found.copyWith(
      toolCall: AIChatMessageToolCallQueryModel(
        query: found.toolCall.query,
        execState: AIChatToolQueryState.rejected,
      ),
    );
    ref.read(aiChatRepoProvider).updateMessageById(chatId, messageId, AIChatMessageItem.toolsResult(rejected));
    onInvalidate();
  }

  @override
  Future<void> approvePending(Ref ref, AIChatId chatId, AIChatMessageId messageId, void Function() onInvalidate) async {
    final found = ref
        .read(aiChatRepoProvider)
        .getMessageById(chatId, messageId)
        ?.maybeWhen(
          toolsResult: (t) => t,
          orElse: () => null,
        );
    if (found == null || !found.toolCall.isAwaitingUserConfirm) return;

    final query = found.toolCall.query;
    final running = found.copyWith(
      toolCall: AIChatMessageToolCallQueryModel(
        query: query,
        execState: AIChatToolQueryState.running,
      ),
    );
    ref.read(aiChatRepoProvider).updateMessageById(chatId, messageId, AIChatMessageItem.toolsResult(running));
    onInvalidate();
  }
}
