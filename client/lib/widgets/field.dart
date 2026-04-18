import 'package:client/l10n/app_localizations.dart';
import 'package:client/widgets/button.dart';
import 'package:client/widgets/const.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sql_editor/re_editor.dart';


abstract final class FormFieldValidators {
  static String? requiredValue(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) {
      return l10n.field_val_msg_value_reqiured;
    }
    return null;
  }

  static FormFieldValidator required(AppLocalizations l10n) {
    return (value) => requiredValue(l10n, value);
  }
}

class TrackedFormController extends ChangeNotifier {
  final Map<String, String> _invalidFieldGroups = {};
  final Map<String, GlobalKey<FormFieldState>> _lazyFormFieldKeys = {};

  String _groupIdForFieldName(String fieldName) => fieldName;

  GlobalKey<FormFieldState> _formFieldKey(String fieldName) {
    return _lazyFormFieldKeys.putIfAbsent(fieldName, () => GlobalKey<FormFieldState>());
  }

  void _reportField(String fieldName, bool valid, {String? groupId}) {
    final newGid = valid ? null : (groupId ?? _groupIdForFieldName(fieldName));
    final oldGid = _invalidFieldGroups[fieldName];
    if (newGid == oldGid) {
      return;
    }
    if (newGid == null) {
      _invalidFieldGroups.remove(fieldName);
    } else {
      _invalidFieldGroups[fieldName] = newGid;
    }
    notifyListeners();
  }

  bool _isGroupValid(String groupId) => !_invalidFieldGroups.containsValue(groupId);

  /// 提交前校验：对已登记 [GlobalKey] 的全部字段逐项 [validate]。
  bool validate() {
    var ok = true;
    for (final key in _lazyFormFieldKeys.values) {
      if (key.currentState?.validate() != true) {
        ok = false;
      }
    }
    return ok;
  }

  void resetInvalidGroups() {
    if (_invalidFieldGroups.isEmpty) {
      return;
    }
    _invalidFieldGroups.clear();
    notifyListeners();
  }
}

/// 向子树注入 [TrackedFormController]；[Tracked*] 在 build 内通过 [TrackedFormScope.of](context) 取得同一实例。
class TrackedFormScope extends InheritedWidget {
  const TrackedFormScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final TrackedFormController controller;

  static TrackedFormController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TrackedFormScope>();
    assert(scope != null, 'TrackedFormScope not found');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(TrackedFormScope oldWidget) => !identical(oldWidget.controller, controller);
}

class TrackedForm extends StatelessWidget {
  const TrackedForm({
    super.key,
    required this.controller,
    required this.child,
  }) : children = null,
       tabLabels = const {};

  const TrackedForm.tabbed({
    super.key,
    required this.controller,
    this.tabLabels = const {},
    required this.children,
  }) : child = null;

  final TrackedFormController controller;
  final Widget? child;
  final List<Widget>? children;

  /// [groupId] -> Tab 标题；未出现的 [groupId] 使用 [groupId] 字符串本身。
  final Map<String, String> tabLabels;

  @override
  Widget build(BuildContext context) {
    if (children != null) {
      return TrackedFormScope(
        controller: controller,
        child: _TrackedFormTabbedLayout(
          controller: controller,
          tabLabels: tabLabels,
          children: children!,
        ),
      );
    }
    return TrackedFormScope(
      controller: controller,
      child: child!,
    );
  }
}

class _TrackedFormTabbedLayout extends StatefulWidget {
  const _TrackedFormTabbedLayout({
    required this.controller,
    required this.tabLabels,
    required this.children,
  });

  final TrackedFormController controller;
  final Map<String, String> tabLabels;
  final List<Widget> children;

  @override
  State<_TrackedFormTabbedLayout> createState() => _TrackedFormTabbedLayoutState();
}

class _TrackedFormTabbedLayoutState extends State<_TrackedFormTabbedLayout> {
  String? _selectedGroup;

  static String? _tabGroupId(Widget w, TrackedFormController c) {
    if (w is TrackedFormField) {
      return w.resolveGroupId(c);
    }
    if (w is TrackedHostPortFields) {
      return w.groupId ?? c._groupIdForFieldName(w.hostFieldName);
    }
    return null;
  }

  /// 单趟遍历：保持首次出现顺序，同时收集每个分组的 children。
  static ({List<String> order, Map<String, List<Widget>> byGroup}) _partition(
    List<Widget> children,
    TrackedFormController c,
  ) {
    final order = <String>[];
    final byGroup = <String, List<Widget>>{};
    for (final w in children) {
      final gid = _tabGroupId(w, c);
      if (gid == null) {
        continue;
      }
      final bucket = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <Widget>[];
      });
      bucket.add(w);
    }
    return (order: order, byGroup: byGroup);
  }

  @override
  void initState() {
    super.initState();
    final order = _partition(widget.children, widget.controller).order;
    _selectedGroup = order.isNotEmpty ? order.first : null;
  }

  @override
  void didUpdateWidget(_TrackedFormTabbedLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final order = _partition(widget.children, widget.controller).order;
    if (order.isEmpty) {
      if (_selectedGroup != null) {
        setState(() => _selectedGroup = null);
      }
      return;
    }
    if (_selectedGroup == null || !order.contains(_selectedGroup)) {
      setState(() => _selectedGroup = order.first);
    }
  }

  void _onSelectGroup(String section) {
    setState(() => _selectedGroup = section);
  }

  @override
  Widget build(BuildContext context) {
    final parts = _partition(widget.children, widget.controller);
    final order = parts.order;
    if (order.isEmpty) {
      return const SizedBox.shrink();
    }
    final byGroup = parts.byGroup;
    final selected = _selectedGroup;
    final index = selected == null ? 0 : order.indexOf(selected).clamp(0, order.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final section in order)
                Padding(
                  padding: const EdgeInsets.only(right: kSpacingTiny),
                  child: TextButton(
                    onPressed: () => _onSelectGroup(section),
                    style: TextButton.styleFrom(
                      backgroundColor: section == selected ? Theme.of(context).colorScheme.primaryContainer : null,
                    ),
                    child: Text(
                      widget.tabLabels[section] ?? section,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: !TrackedFormScope.of(context)._isGroupValid(section)
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: kSpacingSmall),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [
              for (final g in order)
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall, vertical: kSpacingTiny),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: kSpacingSmall,
                    children: byGroup[g] ?? const <Widget>[],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 与 [TrackedFormController] 联动的表单字段基类（依赖 [TrackedFormScope] 祖先）。
abstract class TrackedFormField extends StatefulWidget {
  /// 与业务 meta 名一致。
  final String fieldName;
  final FormFieldValidator? validator;

  /// 若为空，Tab 分组与校验汇总由控制器按 [fieldName] 回退。
  final String? groupId;

  const TrackedFormField({
    super.key,
    required this.fieldName,
    this.validator,
    this.groupId,
  });

  /// [TrackedForm.tabbed] 用于合并到同一 Tab 的分组 id。
  String resolveGroupId(TrackedFormController controller) => groupId ?? controller._groupIdForFieldName(fieldName);

  /// 包装 [validator]：校验后向 [TrackedFormController] 回报结果，驱动 Tab 标红。
  FormFieldValidator? resolveValidator(BuildContext context) {
    final inner = validator;
    if (inner == null) {
      return null;
    }
    final form = TrackedFormScope.of(context);
    return (value) {
      final err = inner(value);
      form._reportField(fieldName, err == null, groupId: groupId);
      return err;
    };
  }

  /// 描边样式的 [InputDecoration]；子类共用。
  static InputDecoration outlineDecoration({
    required String label,
    EdgeInsetsGeometry? contentPadding,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      labelText: label,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      helperText: helperText,
      suffixIcon: suffixIcon,
    );
  }
}

/// 标准单行文本，带描边样式；可选 [suffixIconBuilder] 在 [build] 中取 [Theme]。
class TrackedTextFormField extends TrackedFormField {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget Function(BuildContext context)? suffixIconBuilder;
  final EdgeInsetsGeometry? contentPadding;
  final double minHeight;

  const TrackedTextFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.obscureText = false,
    this.suffixIcon,
    this.suffixIconBuilder,
    this.contentPadding,
    this.minHeight = 80,
  });

  @override
  State<TrackedTextFormField> createState() => _TrackedTextFormFieldState();
}

class _TrackedTextFormFieldState extends State<TrackedTextFormField> {
  @override
  Widget build(BuildContext context) {
    final form = TrackedFormScope.of(context);
    final suffix = widget.suffixIcon ?? widget.suffixIconBuilder?.call(context);
    return Container(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      child: TextFormField(
        key: form._formFieldKey(widget.fieldName),
        readOnly: widget.readOnly,
        obscureText: widget.obscureText,
        autovalidateMode: AutovalidateMode.onUnfocus,
        controller: widget.controller,
        validator: widget.resolveValidator(context),
        decoration: TrackedFormField.outlineDecoration(
          label: widget.label,
          contentPadding: widget.contentPadding,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

/// 本地文件路径：单行输入 + 文件夹按钮；点击用 [FilePicker] 选文件并写入 [controller]，再触发表单校验。
class TrackedFilePathFormField extends TrackedFormField {
  const TrackedFilePathFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required this.label,
    required this.controller,
    required this.pickTooltip,
    this.allowedExtensions = const ['db', 'sqlite', 'sqlite3'],
    this.minHeight = 80,
  });

  final String label;
  final TextEditingController controller;
  final String pickTooltip;
  final List<String> allowedExtensions;
  final double minHeight;

  @override
  State<TrackedFilePathFormField> createState() => _TrackedFilePathFormFieldState();
}

class _TrackedFilePathFormFieldState extends State<TrackedFilePathFormField> {
  Future<void> _pickFile() async {
    final ctrl = widget.controller;
    final currentPath = ctrl.text.trim();
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: currentPath.isNotEmpty ? p.dirname(currentPath) : null,
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
    );
    if (!mounted) {
      return;
    }
    final files = result?.files;
    final filePath = (files != null && files.isNotEmpty) ? files.first.path : null;
    if (filePath != null && filePath.isNotEmpty) {
      ctrl.text = filePath;
      TrackedFormScope.of(context)._formFieldKey(widget.fieldName).currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrackedTextFormField(
      fieldName: widget.fieldName,
      validator: widget.validator,
      groupId: widget.groupId,
      label: widget.label,
      controller: widget.controller,
      contentPadding: const EdgeInsets.all(kSpacingSmall),
      minHeight: widget.minHeight,
      suffixIconBuilder: (context) => Padding(
        padding: const EdgeInsets.only(right: kSpacingTiny),
        child: RectangleIconButton.medium(
          icon: Icons.folder_open,
          tooltip: widget.pickTooltip,
          iconColor: Theme.of(context).colorScheme.primary,
          onPressed: _pickFile,
        ),
      ),
    );
  }
}

/// [CodeLineEditingController] + 自定义 [child]（通常为 [CodeEditor]），与其它 [Tracked*] 一样参与 [validate] 与 Tab 分组；[fieldName] / [groupId] 由业务页约定。
class TrackedCodeEditorFormField extends TrackedFormField {
  const TrackedCodeEditorFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required this.codeController,
    required this.child,
  });

  final CodeLineEditingController codeController;
  final Widget child;

  @override
  State<TrackedCodeEditorFormField> createState() => _TrackedCodeEditorFormFieldState();
}

class _TrackedCodeEditorFormFieldState extends State<TrackedCodeEditorFormField> {
  @override
  void initState() {
    super.initState();
    widget.codeController.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(TrackedCodeEditorFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.codeController != widget.codeController) {
      oldWidget.codeController.removeListener(_sync);
      widget.codeController.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.codeController.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) {
      return;
    }
    TrackedFormScope.of(context)
        ._formFieldKey(widget.fieldName)
        .currentState
        ?.didChange(widget.codeController.text);
  }

  @override
  Widget build(BuildContext context) {
    final form = TrackedFormScope.of(context);
    return FormField<String>(
      key: form._formFieldKey(widget.fieldName),
      initialValue: widget.codeController.text,
      autovalidateMode: AutovalidateMode.onUnfocus,
      validator: widget.resolveValidator(context),
      builder: (_) => widget.child,
    );
  }
}

/// 主机 + 可选端口同一组件；端口相关参数须**整组提供或整组省略**（省略时仅显示主机）。
class TrackedHostPortFields extends StatelessWidget {
  const TrackedHostPortFields({
    super.key,
    required this.hostFieldName,
    required this.hostController,
    required this.hostValidator,
    required this.hostLabel,
    this.portFieldName,
    this.portController,
    this.portValidator,
    this.portLabel,
    this.groupId,
  }) : assert(
         (portFieldName == null) == (portController == null && portValidator == null && portLabel == null),
       );

  /// 若为空，[TrackedForm.tabbed] 对主机字段按 [hostFieldName] 向控制器回退分组。
  final String? groupId;

  final String hostFieldName;
  final TextEditingController hostController;
  final FormFieldValidator hostValidator;
  final String hostLabel;
  final String? portFieldName;
  final TextEditingController? portController;
  final FormFieldValidator? portValidator;
  final String? portLabel;

  @override
  Widget build(BuildContext context) {
    final hostField = TrackedTextFormField(
      fieldName: hostFieldName,
      validator: hostValidator,
      groupId: groupId,
      label: hostLabel,
      controller: hostController,
    );
    final pk = portFieldName;
    final pc = portController;
    final pv = portValidator;
    final pl = portLabel;
    if (pk == null) {
      return hostField;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: hostField),
          const SizedBox(width: kSpacingSmall),
          Container(
            constraints: const BoxConstraints(maxWidth: 132),
            child: TrackedTextFormField(
              fieldName: pk,
              validator: pv!,
              groupId: groupId,
              label: pl!,
              controller: pc!,
            ),
          ),
        ],
      ),
    );
  }
}

/// 密码单行输入；与 [TrackedTextFormField] 相同，但 [obscureText] 恒为 true。
class TrackedPasswordFormField extends TrackedTextFormField {
  const TrackedPasswordFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required super.label,
    required super.controller,
    super.suffixIcon,
    super.suffixIconBuilder,
    super.contentPadding,
    super.minHeight,
  }) : super(
         readOnly: false,
         obscureText: true,
       );
}

/// 多行文本（描述、备注等）。
class TrackedMultilineFormField extends TrackedFormField {
  final String label;
  final TextEditingController controller;
  final int? maxLength;
  final int maxLines;
  final EdgeInsetsGeometry? contentPadding;
  final double minHeight;

  const TrackedMultilineFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required this.label,
    required this.controller,
    this.maxLength = 50,
    this.maxLines = 4,
    this.contentPadding,
    this.minHeight = 120,
  });

  @override
  State<TrackedMultilineFormField> createState() => _TrackedMultilineFormFieldState();
}

class _TrackedMultilineFormFieldState extends State<TrackedMultilineFormField> {
  @override
  Widget build(BuildContext context) {
    final form = TrackedFormScope.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      child: TextFormField(
        key: form._formFieldKey(widget.fieldName),
        controller: widget.controller,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        autovalidateMode: AutovalidateMode.onUnfocus,
        validator: widget.resolveValidator(context),
        decoration: TrackedFormField.outlineDecoration(
          label: widget.label,
          contentPadding: widget.contentPadding ?? const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

/// 多行描述/备注；默认内边距为 [kSpacingSmall]，其余与 [TrackedMultilineFormField] 一致。
class TrackedDescFormField extends TrackedMultilineFormField {
  const TrackedDescFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required super.label,
    required super.controller,
    super.maxLength = 50,
    super.maxLines = 4,
    super.minHeight = 120,
  }) : super(
         contentPadding: const EdgeInsets.all(kSpacingSmall),
       );
}

/// 与 [TrackedTextFormField] 视觉一致的下拉框；选中值写入 [controller]。
///
/// 使用 [DropdownButtonFormField] 的 [initialValue]（Flutter 3.33+），以便外部改写 [controller] 时通过重建同步。
class TrackedEnumFormField extends TrackedFormField {
  final String label;
  final TextEditingController controller;
  final List<String> enumValues;
  final String? defaultValue;
  final String? helperText;

  const TrackedEnumFormField({
    super.key,
    required super.fieldName,
    super.validator,
    super.groupId,
    required this.label,
    required this.controller,
    required this.enumValues,
    this.defaultValue,
    this.helperText,
  });

  @override
  State<TrackedEnumFormField> createState() => _TrackedEnumFormFieldState();
}

class _TrackedEnumFormFieldState extends State<TrackedEnumFormField> {
  static String _effectiveValue(
    List<String> opts,
    String current,
    String? defaultValue,
  ) {
    if (opts.isEmpty) {
      return current;
    }
    if (opts.contains(current)) {
      return current;
    }
    if (defaultValue != null && opts.contains(defaultValue)) {
      return defaultValue;
    }
    return opts.first;
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.enumValues;
    if (opts.isEmpty) {
      return TrackedTextFormField(
        fieldName: widget.fieldName,
        validator: widget.validator,
        groupId: widget.groupId,
        label: widget.label,
        controller: widget.controller,
      );
    }
    final effective = _effectiveValue(
      opts,
      widget.controller.text,
      widget.defaultValue,
    );
    if (widget.controller.text != effective) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.text != effective) {
          widget.controller.text = effective;
        }
      });
    }
    final form = TrackedFormScope.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      child: DropdownButtonFormField<String>(
        key: form._formFieldKey(widget.fieldName),
        autovalidateMode: AutovalidateMode.onUnfocus,
        isExpanded: true,
        decoration: TrackedFormField.outlineDecoration(
          label: widget.label,
          helperText: widget.helperText,
        ),
        initialValue: effective,
        items: opts
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            widget.controller.text = v;
          }
        },
        validator: widget.resolveValidator(context),
      ),
    );
  }
}
