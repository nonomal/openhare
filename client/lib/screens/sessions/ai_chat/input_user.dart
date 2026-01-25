import 'package:client/l10n/app_localizations.dart';
import 'package:client/models/ai.dart';
import 'package:client/models/sessions.dart';
import 'package:client/services/ai/agent.dart';
import 'package:client/services/ai/chat.dart';
import 'package:client/services/ai/prompt.dart';
import 'package:client/services/sessions/session_controller.dart';
import 'package:client/widgets/button.dart';
import 'package:client/widgets/const.dart';
import 'package:client/widgets/loading.dart';
import 'package:client/widgets/menu.dart';
import 'package:client/widgets/tooltip.dart';
import 'package:db_driver/db_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class SessionChatInputCard extends ConsumerStatefulWidget {
  final SessionAIChatModel model;

  const SessionChatInputCard({super.key, required this.model});

  @override
  ConsumerState<SessionChatInputCard> createState() => _SessionChatInputCardState();
}

class _SessionChatInputCardState extends ConsumerState<SessionChatInputCard> {
  void _onSearchChanged() {
    setState(() {});
  }

  bool _isTableSelected(SessionAIChatModel model, String tableName) {
    return model.chatModel.tables.containsKey(model.currentSchema ?? "") &&
        model.chatModel.tables[model.currentSchema ?? ""]!.containsKey(tableName);
  }

  Map<String, String> _allTable(SessionAIChatModel model, String searchText) {
    if (model.metadata == null || model.currentSchema == null) {
      return {};
    }
    return MetaDataNode(MetaType.instance, "", items: model.metadata!)
        .getChildren(MetaType.schema, model.currentSchema!)
        .where((e) => e.type == MetaType.table && e.value.contains(searchText))
        .fold({}, (acc, e) => {...acc, e.value: e.value});
  }

  bool _isAllTableSelected(SessionAIChatModel model, String searchText) {
    final allTable = _allTable(model, searchText);

    if (!model.chatModel.tables.containsKey(model.currentSchema ?? "")) {
      return false;
    }

    for (var table in allTable.keys) {
      if (!model.chatModel.tables[model.currentSchema ?? ""]!.containsKey(table)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _sendMessage(AIChatId chatId, SessionAIChatModel chatModel) async {
    final text = SessionController.sessionController(chatModel.sessionId).chatInputController.text.trim();
    SessionController.sessionController(chatModel.sessionId).chatInputController.clear();

    // 调用AIChatService的chat方法
    await ref.read(aIChatServiceProvider.notifier).chat(
          chatId,
          chatModel.llmAgents.lastUsedLLMAgent!.id,
          genChatSystemPrompt(chatModel),
          message: text,
        );

    final scrollController = SessionController.sessionController(chatModel.sessionId).aiChatScrollController;

    // 滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.read(aIChatServiceProvider.notifier);

    final chatInputController = SessionController.sessionController(widget.model.sessionId).chatInputController;
    final searchTextController = SessionController.sessionController(widget.model.sessionId).aiChatSearchTextController;

    // 模型选择工具栏
    final modelToolWidget = Container(
      constraints: const BoxConstraints(
        maxWidth: 120,
      ),
      padding: const EdgeInsets.fromLTRB(kSpacingSmall, kSpacingTiny, kSpacingSmall, kSpacingTiny),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          width: 1,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: Text(
        widget.model.llmAgents.lastUsedLLMAgent?.setting.name ?? "-",
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );

    final tableCount = widget.model.chatModel.tables[widget.model.currentSchema ?? ""]?.length ?? 0;

    // 表选择工具栏
    final tableToolWidget = IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 80,
        ),
        padding: const EdgeInsets.fromLTRB(kSpacingSmall, kSpacingTiny, kSpacingSmall, kSpacingTiny),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 1,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTable,
              color: Theme.of(context).colorScheme.onSurface,
              size: kIconSizeSmall,
            ),
            const SizedBox(width: kSpacingTiny),
            Expanded(
              child: (tableCount > 10)
                  ? Tooltip(
                      message: AppLocalizations.of(context)!.ai_chat_table_tip_more_than_10,
                      child: Text(
                        "+$tableCount",
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    )
                  : Text(
                      "+$tableCount",
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpacingSmall - 5, 0, kSpacingSmall, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(kSpacingSmall, kSpacingSmall, kSpacingSmall, kSpacingTiny),
        // 设置一个圆角
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            // 输入框
            TextField(
              style: Theme.of(context).textTheme.bodyMedium,
              controller: chatInputController,
              minLines: 1,
              maxLines: 5,
              enabled: widget.model.chatModel.state != AIChatState.waiting,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.ai_chat_input_tip,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: kSpacingSmall, horizontal: kSpacingTiny),
              ),
              onSubmitted: (_) =>
                  widget.model.canSendMessage() ? _sendMessage(widget.model.chatModel.id, widget.model) : null,
            ),

            const SizedBox(height: kSpacingSmall),

            // 工具栏
            Row(
              children: [
                const SizedBox(width: kSpacingTiny),
                // 模型选择
                OverlayMenu(
                  isAbove: true,
                  spacing: kSpacingTiny,
                  tabs: [
                    for (var agent in widget.model.llmAgents.agents.values)
                      OverlayMenuItem(
                        height: 24,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(kSpacingSmall, 0, kSpacingSmall, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              agent.setting.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        onTabSelected: () {
                          ref.read(lLMAgentServiceProvider.notifier).updateLastUsedLLMAgent(agent.id);
                        },
                      ),
                  ],
                  child: modelToolWidget,
                ),
                const SizedBox(width: kSpacingTiny),

                // 表选择
                (widget.model.currentSchema != null && widget.model.currentSchema != "")
                    ? OverlayMenu(
                        isAbove: true,
                        closeOnSelectItem: false,
                        spacing: kSpacingTiny,
                        tabs: [
                          for (var table in _allTable(widget.model, searchTextController.text).keys)
                            OverlayMenuItem(
                              height: 36,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(kSpacingSmall, 0, kSpacingSmall, 0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      // 如果table 在aichatmodel.tables 中，则显示选中状态
                                      _isTableSelected(widget.model, table)
                                          ? const Icon(
                                              Icons.check_circle,
                                              size: kIconSizeSmall,
                                              color: Colors.green,
                                            )
                                          : const Icon(
                                              Icons.circle_outlined,
                                              size: kIconSizeSmall,
                                            ),
                                      const SizedBox(width: kSpacingTiny),
                                      Expanded(
                                        child: TooltipText(text: table, style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              onTabSelected: () {
                                final newTables = Map<String, String>.from(
                                    widget.model.chatModel.tables[widget.model.currentSchema ?? ""] ?? {});

                                if (_isTableSelected(widget.model, table)) {
                                  // delete it
                                  newTables.remove(table);
                                  services.updateTables(
                                      widget.model.chatModel.id, widget.model.currentSchema ?? "", newTables);
                                  return;
                                } else {
                                  // 如果table 不在aichatmodel.tables 中，则添加
                                  newTables[table] = table;
                                  services.updateTables(
                                      widget.model.chatModel.id, widget.model.currentSchema ?? "", newTables);
                                }
                              },
                            ),
                        ],
                        footer: OverlayMenuFooter(
                          height: 36,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(kSpacingSmall, kSpacingTiny, kSpacingSmall, kSpacingTiny),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    // 全选或者全取消操作
                                    if (_isAllTableSelected(widget.model, searchTextController.text)) {
                                      // 全取消
                                      services.updateTables(
                                          widget.model.chatModel.id, widget.model.currentSchema ?? "", {});
                                    } else {
                                      // 全选
                                      services.updateTables(
                                        widget.model.chatModel.id,
                                        widget.model.currentSchema ?? "",
                                        _allTable(widget.model, searchTextController.text),
                                      );
                                    }
                                  },
                                  child: Icon(
                                    _isAllTableSelected(widget.model, searchTextController.text)
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: kIconSizeSmall,
                                    color: _isAllTableSelected(widget.model, searchTextController.text)
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: kSpacingTiny),
                                Expanded(
                                  child: SearchBarTheme(
                                    data: SearchBarThemeData(
                                        textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.bodySmall),
                                        backgroundColor:
                                            WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainer),
                                        elevation: const WidgetStatePropertyAll(0),
                                        constraints: const BoxConstraints(
                                          minHeight: 24,
                                        )),
                                    child: SearchBar(
                                        controller: searchTextController,
                                        onChanged: (value) {
                                          _onSearchChanged();
                                        },
                                        trailing: const [
                                          Icon(
                                            Icons.search,
                                            size: kIconSizeSmall,
                                          ),
                                        ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: tableToolWidget,
                      )
                    : OverlayMenu(
                        isAbove: true,
                        spacing: kSpacingTiny,
                        tabs: const [],
                        footer: OverlayMenuFooter(
                          height: 200,
                          child: Padding(
                            padding: const EdgeInsets.all(kSpacingSmall),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline,
                                    size: kIconSizeMedium, color: Theme.of(context).colorScheme.onSurface),
                                const SizedBox(height: kSpacingSmall),
                                Text(
                                  AppLocalizations.of(context)!.ai_chat_table_tip,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: tableToolWidget,
                      ),
                const Spacer(),

                // 清空聊天记录
                RectangleIconButton.small(
                  tooltip: AppLocalizations.of(context)!.button_tooltip_clear_chat,
                  icon: Icons.cleaning_services,
                  onPressed:
                      widget.model.canClearMessage() ? () => services.cleanMessages(widget.model.chatModel.id) : null,
                ),

                // 发送消息
                (widget.model.chatModel.state == AIChatState.waiting)
                    ? const Loading.small()
                    : RectangleIconButton.small(
                        tooltip: AppLocalizations.of(context)!.button_tooltip_send_message,
                        icon: Icons.send,
                        onPressed: widget.model.canSendMessage()
                            ? () => _sendMessage(widget.model.chatModel.id, widget.model)
                            : null,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
