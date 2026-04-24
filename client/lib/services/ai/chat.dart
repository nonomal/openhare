import 'package:client/models/ai.dart';
import 'package:client/models/sessions.dart';
import 'package:client/repositories/ai/agent.dart';
import 'package:client/repositories/ai/chat.dart';
import 'package:client/services/ai/llm_sdk.dart';
import 'package:client/services/ai/tool.dart';
import 'package:client/services/sessions/session_conn.dart';
import 'package:client/services/sessions/sessions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:client/utils/state_value.dart';

part 'chat.g.dart';

@Riverpod(keepAlive: true)
class AIChatService extends _$AIChatService {
  @override
  int build() {
    return 0;
  }

  void _invalidateSelf() {
    state++;
  }

  void _updateProgress(AIChatId id, AIChatProgressModel progress) {
    ref.read(aiChatRepoProvider).updateProgress(id, progress);
  }

  AIChatModel? getAIChatById(AIChatId id) {
    return ref.read(aiChatRepoProvider).getAIChatById(id);
  }

  AIChatOverviewModel? getAIChatOverview(AIChatId id) {
    return ref.read(aiChatRepoProvider).getAIChatOverview(id);
  }

  void create(AIChatModel model) {
    ref.read(aiChatRepoProvider).create(model);
  }

  List<AIChatMessageItem> _getChatMessage(AIChatId id) {
    return ref.read(aiChatRepoProvider).getAIChatById(id)?.messages ?? [];
  }

  AIChatMessageItem? getMessageByIndex(AIChatId id, int index) {
    return ref.read(aiChatRepoProvider).getMessageByIndex(id, index);
  }

  void _updateState(AIChatId id, AIChatState state) {
    ref.read(aiChatRepoProvider).updateState(id, state);
    _invalidateSelf();
  }

  /// 检查当前 chat 是否处于 cancel 状态
  bool _isCancelled(AIChatId id) {
    return ref.read(aiChatRepoProvider).isCancel(id);
  }

  /// 通过最后一条消息判断是否正在执行工具（query）
  bool _isExecutingTool(AIChatId id) {
    final model = ref.read(aiChatRepoProvider).getAIChatOverview(id);
    if (model == null) {
      return false;
    }
    final last = model.latestMessage;
    if (last == null) {
      return false;
    }
    return last.maybeWhen(
      toolsResult: (toolsResult) => toolsResult.toolCall.execState == AIChatToolQueryState.running,
      orElse: () => false,
    );
  }

  /// 用户主动取消当前 chat
  void cancelChat(AIChatId id) {
    _updateState(id, AIChatState.cancel);

    // 仅当正在执行工具（通过最后一条消息判断，目前只有 query）时，kill 掉正在执行的 query
    if (!_isExecutingTool(id)) {
      return;
    }
    final sessionId = SessionId(value: id.value);
    final sessionModel = ref.read(sessionsServicesProvider.notifier).getSession(sessionId);
    if (sessionModel != null && sessionModel.connId != null) {
      ref.read(sessionConnsServicesProvider.notifier).killQuery(sessionModel.connId!);
    }
  }

  Future<void> resolveToolQueryExecution(
    AIChatId chatId,
    AIChatMessageId messageId,
    bool approved,
    LLMAgentId agentId,
    String systemPrompt,
  ) async {
    final model = ref.read(aiChatRepoProvider).getMessageById(chatId, messageId);
    if (model == null) {
      return;
    }
    final toolsModel = model.maybeWhen(
      toolsResult: (m) => m,
      orElse: () => null,
    );
    if (toolsModel == null) {
      return;
    }
    final executor = createAIChatToolExecutorFromModel(toolsModel);
    if (executor == null) return;
    if (!approved) {
      // 用户拒绝执行该 SQL
      executor.setStatus(ref, chatId, AIChatToolQueryState.rejected, onInvalidate: _invalidateSelf);
      return;
    } else {
      // 用户确认执行该 SQL
      executor.setStatus(ref, chatId, AIChatToolQueryState.approved, onInvalidate: _invalidateSelf);
      await executor.run(ref, chatId, onInvalidate: _invalidateSelf);
    }
    // 继续对话
    await chat(chatId, agentId, systemPrompt);
  }

  /// 进行AI对话，请求接口，存储消息并刷新使用 provider 来动态刷新页面
  Future<void> chat(
    AIChatId chatId,
    LLMAgentId agentId,
    String systemPrompt, {
    String? message,
    String? refText,
  }) async {
    // 获取当前选中的 LLM Agent
    LLMAgentModel? lastUsedLLMAgent = ref.read(lLMAgentRepoProvider).getLastUsedLLMAgent();
    if (lastUsedLLMAgent == null) {
      return;
    }

    final repo = ref.read(aiChatRepoProvider);
    final model = repo.getAIChatById(chatId);
    if (model == null) {
      return;
    }

    // 0. 预算状态：上下文硬停后无法继续
    if (model.progress.contextHardStopped) {
      return;
    }
    // 每次主动对话设置50轮数，自动 loop 一次最大50.
    _updateProgress(chatId, model.progress.copyWith(loopLimit: 50, loopUsed: 0));

    // 1.如果有则更新用户提问的消息
    if (message != null) {
      final messageModel = AIChatUserMessageModel(id: AIChatMessageId.generate(), content: message, ref: refText);
      repo.addMessage(chatId, AIChatMessageItem.userMessage(messageModel));
    }

    _updateState(chatId, AIChatState.waiting);

    final llmSdk = LLMProvider.create(lastUsedLLMAgent.setting, systemPrompt, tools: [QueryTool()]);

    chatLoop:
    while (true) {
      final model = repo.getAIChatById(chatId);
      if (model == null) {
        break; // 几乎不会发生
      }
      // 每次 loop 开始时检查是否被取消
      if (_isCancelled(chatId)) {
        break;
      }
      // loop 上限后无法继续
      if (model.progress.loopStopped) {
        break;
      }
      // 上下文硬停后无法继续
      if (model.progress.contextHardStopped) {
        break;
      }

      AIChatAssistantMessageModel lastMessage = AIChatAssistantMessageModel(
        id: AIChatMessageId.generate(),
        content: '',
        status: State.running,
      );
      repo.addMessage(chatId, AIChatMessageItem.assistantMessage(lastMessage));

      ChatUsage? usage;

      List<AIChatMessageToolCall> toolCalls = [];
      try {
        await for (final chunk in llmSdk.stream(model.messages)) {
          if (_isCancelled(chatId)) {
            break;
          }
          usage = chunk.usage;
          toolCalls = chunk.toolCalls ?? [];
          lastMessage = lastMessage.copyWith(
            content: chunk.content,
            thinking: chunk.thinking,
          );
          // 数据始终更新到 repo
          repo.updateMessage(chatId, AIChatMessageItem.assistantMessage(lastMessage));
          _invalidateSelf();
        }

        // 更新统计信息
        if (usage != null) {
          _updateProgress(
            chatId,
            model.progress.copyWith(
              totalTokens: usage.totalTokens ?? model.progress.totalTokens,
              loopUsed: model.progress.loopUsed + 1,
            ),
          );
        }
        // 更新对话状态
        lastMessage = lastMessage.copyWith(status: State.done);
        repo.updateMessage(chatId, AIChatMessageItem.assistantMessage(lastMessage));

        _invalidateSelf();
      } catch (e) {
        lastMessage = lastMessage.copyWith(
          error: e.toString(),
          status: State.failing,
        );
        repo.updateMessage(chatId, AIChatMessageItem.assistantMessage(lastMessage));
        _invalidateSelf();
        break;
      }

      if (toolCalls.isNotEmpty) {
        for (final toolCall in toolCalls) {
          // 每个工具执行前检查是否被取消
          if (_isCancelled(chatId)) {
            break;
          }
          final executor = createAIChatToolExecutor(toolCall);
          if (executor != null) {
            executor.initMessage(ref, chatId);
            if (executor.checkNeedsAwaitUserConfirm(ref, chatId)) {
              // 如果需要用户确认，则写入待确认状态，并结束本轮 chat
              executor.setStatus(
                ref,
                chatId,
                AIChatToolQueryState.awaitingUserConfirm,
                onInvalidate: _invalidateSelf,
              );
              break chatLoop;
            } else {
              // 如果不需要用户确认, 则自动批准，并执行工具.
              executor.setStatus(ref, chatId, AIChatToolQueryState.approved, onInvalidate: _invalidateSelf);
              await executor.run(ref, chatId, onInvalidate: _invalidateSelf);
            }
          }
        }
        continue;
      }
      // 正常完成（无工具调用时默认结束）
      break;
    }
    // 用户已取消对话时不要覆盖为 idle，否则 UI 无法区分「已取消」
    if (!_isCancelled(chatId)) {
      _updateState(chatId, AIChatState.idle);
    }
  }

  void retryChat(AIChatId id, LLMAgentId agentId, String systemPrompt, AIChatUserMessageModel retryMessage) {
    final messages = _getChatMessage(id);
    final newMessages = <AIChatMessageItem>[];
    for (final message in messages) {
      if (message.messageId == retryMessage.id) {
        newMessages.add(AIChatMessageItem.userMessage(retryMessage));
        break;
      } else {
        newMessages.add(message);
      }
    }
    ref.read(aiChatRepoProvider).updateMessages(id, newMessages);
    _invalidateSelf();
    chat(id, agentId, systemPrompt);
    return;
  }

  void cleanMessages(AIChatId id) {
    ref.read(aiChatRepoProvider).updateMessages(id, []);
    ref.read(aiChatRepoProvider).updateProgress(id, const AIChatProgressModel());
    _invalidateSelf();
  }

  void delete(AIChatId id) {
    ref.read(aiChatRepoProvider).delete(id);
    _invalidateSelf();
  }
}
