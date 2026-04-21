import 'package:flutter/material.dart';

/// 分割视图控制器
/// first 区域总是自适应（Expanded），second 区域固定大小（可拖拽调整）
class SplitViewController extends ChangeNotifier {
  /// first 区域的最小尺寸
  final double firstMinSize;

  /// second 区域的最小尺寸
  final double secondMinSize;

  /// 分割条厚度（与 [SplitView] 中分割条一致）
  final double dividerThickness;

  /// 当前 second 区域的大小（拖拽时可能改变）
  double _secondSize;

  double get secondSize => _secondSize;

  SplitViewController({
    required double secondSize,
    this.firstMinSize = 0,
    this.secondMinSize = 0,
    this.dividerThickness = 5.0,
  }) : _secondSize = secondSize;

  void syncSecondToLayoutTotalSize(double totalSize) {
    _secondSize = _applySecondPanDelta(totalSize, 0);
    // 无需更新订阅, 这个函数在build内调用, 后续会读到新的secondSize.
  }

  void applyPanSecondDelta(double totalSize, double delta) {
    _secondSize = _applySecondPanDelta(totalSize, delta);
    notifyListeners();
  }

  double _applySecondPanDelta(double totalSize, double delta) {
    if (totalSize <= 0) return _secondSize;
    // 计算最大second size, 必须确保留下最小的first size.
    final double secondMaxSize = totalSize - dividerThickness - firstMinSize;
    final double newSecondSize = _secondSize - delta;
    return newSecondSize.clamp(secondMinSize, secondMaxSize);
  }
}

class SplitView extends StatefulWidget {
  final SplitViewController controller;
  final Widget first;
  final Widget second;
  final Axis axis;

  const SplitView({
    super.key,
    required this.controller,
    required this.first,
    required this.second,
    this.axis = Axis.horizontal,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  bool _isDragging = false; // 是否正在拖拽，用于控制 IgnorePointer

  bool get _isHorizontal => widget.axis == Axis.horizontal;

  void _onPanStart() {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(double totalSize, DragUpdateDetails details) {
    final double delta = _isHorizontal ? details.delta.dx : details.delta.dy;
    widget.controller.applyPanSecondDelta(totalSize, delta);
  }

  void _onPanEnd() {
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // 获取最大尺寸
            final double totalSize = (widget.axis == Axis.horizontal) ? constraints.maxWidth : constraints.maxHeight;
            if (totalSize <= 0) return const SizedBox.shrink();

            widget.controller.syncSecondToLayoutTotalSize(totalSize);
            final double dividerThickness = widget.controller.dividerThickness;
            final body = [
              // first 区域
              Expanded(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    ignoring: _isDragging,
                    child: widget.first,
                  ),
                ),
              ),

              // 拖动的分割线
              RepaintBoundary(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // 阻止事件穿透到底层
                  onPanStart: (details) => _onPanStart(),
                  onPanUpdate: (details) => _onPanUpdate(totalSize, details),
                  onPanEnd: (details) => _onPanEnd(),
                  child: SizedBox(
                    width: _isHorizontal ? dividerThickness : double.infinity,
                    height: _isHorizontal ? double.infinity : dividerThickness,
                    child: MouseRegion(
                      cursor: _isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),

              // second 区域
              SizedBox(
                width: _isHorizontal ? widget.controller.secondSize : null,
                height: _isHorizontal ? null : widget.controller.secondSize,
                child: RepaintBoundary(
                  child: IgnorePointer(
                    ignoring: _isDragging,
                    child: widget.second,
                  ),
                ),
              ),
            ];
            return _isHorizontal ? Row(children: body) : Column(children: body);
          },
        );
      },
    );
  }
}
