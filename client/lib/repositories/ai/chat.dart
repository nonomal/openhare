import 'dart:collection';

import 'package:client/models/ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat.g.dart';

class AIChatStorage {
  final AIChatId id;
  final LinkedHashMap<AIChatMessageId, AIChatMessageItem> messages;
  AIChatState state;
  AIChatProgressModel progress;

  AIChatStorage({
    required this.id,
    required this.messages,
    required this.state,
    required this.progress,
  });

  factory AIChatStorage.fromModel(AIChatModel model) {
    return AIChatStorage(
      id: model.id,
      messages: LinkedHashMap.fromEntries(model.messages.map((e) => MapEntry(e.messageId, e))),
      state: model.state,
      progress: model.progress,
    );
  }

  AIChatModel toModel() {
    return AIChatModel(
      id: id,
      messages: messages.values.toList(),
      state: state,
      progress: progress,
    );
  }
}

class AIChatRepoImpl extends AIChatRepo {
  final Map<AIChatId, AIChatStorage> _aiChats = {};

  AIChatRepoImpl();

  @override
  AIChatModel create(AIChatModel model) {
    if (_aiChats.containsKey(model.id)) {
      return _aiChats[model.id]!.toModel();
    }
    _aiChats[model.id] = AIChatStorage.fromModel(model);
    return model;
  }

  @override
  void updateMessages(AIChatId id, List<AIChatMessageItem> messages) {
    final chat = _aiChats[id];
    if (chat == null) {
      return;
    }
    chat.messages.clear();
    for (final message in messages) {
      chat.messages[message.messageId] = message;
    }
  }

  @override
  void updateState(AIChatId id, AIChatState state) {
    final chat = _aiChats[id];
    if (chat == null) {
      return;
    }
    chat.state = state;
  }

  @override
  void updateProgress(AIChatId id, AIChatProgressModel progress) {
    final chat = _aiChats[id];
    if (chat == null) {
      return;
    }
    chat.progress = progress;
  }

  @override
  void delete(AIChatId id) {
    _aiChats.remove(id);
  }

  @override
  AIChatModel? getAIChatById(AIChatId id) {
    final chat = _aiChats[id];
    return chat?.toModel();
  }

  @override
  AIChatOverviewModel? getAIChatOverview(AIChatId id) {
    final chat = _aiChats[id];
    if (chat == null) {
      return null;
    }
    return AIChatOverviewModel(
      id: chat.id,
      messageCount: chat.messages.length,
      state: chat.state,
      progress: chat.progress,
      latestMessage: chat.messages.values.lastOrNull,
    );
  }

  @override
  AIChatMessageItem? getMessageById(AIChatId id, AIChatMessageId messageId) {
    final chat = _aiChats[id];
    if (chat == null) {
      return null;
    }
    return chat.messages[messageId];
  }

  @override
  AIChatMessageItem? getMessageByIndex(AIChatId id, int index) {
    final chat = _aiChats[id];
    if (chat == null) {
      return null;
    }
    return chat.messages.values.elementAtOrNull(index);
  }

  @override
  void addMessage(AIChatId id, AIChatMessageItem message) {
    final chat = _aiChats[id];
    if (chat == null) {
      return;
    }
    assert(!chat.messages.containsKey(message.messageId), 'addMessage requires a new message id');
    chat.messages[message.messageId] = message;
  }

  @override
  void updateMessage(AIChatId chatId, AIChatMessageItem message) {
    final chat = _aiChats[chatId];
    if (chat == null) {
      return;
    }
    if (!chat.messages.containsKey(message.messageId)) {
      return;
    }
    chat.messages[message.messageId] = message;
  }

  @override
  bool isCancel(AIChatId chatId) {
    final chat = _aiChats[chatId];
    if (chat == null) {
      return false;
    }
    return chat.state == AIChatState.cancel;
  }
}

@Riverpod(keepAlive: true)
AIChatRepo aiChatRepo(Ref ref) {
  return AIChatRepoImpl();
}
