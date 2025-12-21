import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'const.dart';

class DataGridController extends ChangeNotifier {
  final List<DataGridColumn> columns;
  final List<DataGridRow> rows;

  // 使用 ValueNotifier 来分别管理选中状态和列宽变化
  final ValueNotifier<Postion?> selectedCellPositionNotifier;
  final ValueNotifier<List<double>> columnWidthNotifier;

  DataGridController({
    required this.columns,
    required this.rows,
    Postion? selectedCellPostion,
  })  : selectedCellPositionNotifier = ValueNotifier(selectedCellPostion),
        columnWidthNotifier = ValueNotifier(columns.map((e) => e.size.width).toList());

  Postion? get selectedCellPostion => selectedCellPositionNotifier.value;
  set selectedCellPostion(Postion? value) => selectedCellPositionNotifier.value = value;

  List<double> get columnWidths => columns.map((e) => e.size.width).toList();

  void updateColumnWidth(int index, double width) {
    if (index >= 0 && index < columns.length) {
      // 确保列宽在合理范围内
      final column = columns[index];
      final clampedWidth = width.clamp(
        column.size.minWidth ?? 50.0,
        column.size.maxWidth ?? double.infinity,
      );
      columns[index].size.width = clampedWidth;
      // 触发列宽变化通知（创建新的列表副本以确保触发更新）
      columnWidthNotifier.value = List<double>.from(columnWidths);
    }
  }

  void updateSelectedCell(Postion p) {
    // 只通知选中状态变化（通过改变值来触发通知）
    selectedCellPositionNotifier.value = p;
  }

  @override
  void dispose() {
    selectedCellPositionNotifier.dispose();
    columnWidthNotifier.dispose();
    super.dispose();
  }
}

class Postion {
  final int rowIndex;
  final int columnIndex;

  const Postion({required this.rowIndex, required this.columnIndex});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Postion && other.rowIndex == rowIndex && other.columnIndex == columnIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

class RowSize {
  /// 实际大小
  double width;

  /// 最小宽度
  final double? minWidth;

  /// 最大宽度
  final double? maxWidth;

  RowSize({
    required this.width,
    this.minWidth = 50.0,
    this.maxWidth = 500.0,
  });
}

/// 列定义
class DataGridColumn {
  final RowSize size;
  final Widget Function(BuildContext context) contentBuilder;

  const DataGridColumn({required this.contentBuilder, required this.size});
}

class DataGridRow {
  final List<DataGridCell> cells;

  const DataGridRow({
    required this.cells,
  });
}

class DataGridCell {
  final String data;

  const DataGridCell({
    required this.data,
  });
}

/// 数据表格组件
class DataGrid extends StatefulWidget {
  /// 数据表格控制器
  final DataGridController controller;

  /// 表头的行高
  final double headerHeight;

  /// 数据行的行高
  final double rowHeight;

  /// 水平滚动控制器组，用于同步表头和数据体的水平滚动
  final LinkedScrollControllerGroup? horizontalScrollGroup;

  /// 垂直滚动控制器，用于数据行的垂直滚动
  final ScrollController? verticalController;

  /// 单元格点击回调
  final void Function(Postion position)? onCellTap;

  /// 单元格双击回调
  final void Function(Postion position)? onCellDoubleTap;

  const DataGrid({
    super.key,
    required this.controller,
    this.rowHeight = 24.0,
    this.headerHeight = 32.0,
    this.horizontalScrollGroup,
    this.verticalController,
    this.onCellTap,
    this.onCellDoubleTap,
  });

  @override
  State<DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<DataGrid> {
  // 滚动控制器管理
  late final LinkedScrollControllerGroup _horizontalScrollGroup;
  late final ScrollController _verticalController;
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;

  @override
  void initState() {
    super.initState();
    // 初始化滚动控制器
    _horizontalScrollGroup = widget.horizontalScrollGroup ?? LinkedScrollControllerGroup();
    _verticalController = widget.verticalController ?? ScrollController();
    _headerHorizontalController = _horizontalScrollGroup.addAndGet();
    _bodyHorizontalController = _horizontalScrollGroup.addAndGet();
  }

  @override
  void dispose() {
    // 清理滚动控制器
    if (widget.verticalController == null) {
      _verticalController.dispose();
    }
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  /// 计算总宽度 - 确保不小于父组件宽度
  double _calculateTotalWidth() {
    final contentWidth = widget.controller.columnWidths.fold(0.0, (sum, width) => sum + width);
    return contentWidth + 12.0;
  }

  double _calculateTotalHeight() {
    return widget.controller.rows.length * widget.rowHeight + 12.0;
  }

  /// 更新列宽
  void _updateColumnWidth(int index, double width) {
    widget.controller.updateColumnWidth(index, width);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<double>>(
      valueListenable: widget.controller.columnWidthNotifier,
      builder: (context, _, __) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        );
      },
    );
  }

  /// 构建表头
  Widget _buildHeader(BuildContext context) {
    final totalWidth = _calculateTotalWidth();
    return SizedBox(
      height: widget.headerHeight,
      child: SingleChildScrollView(
        controller: _headerHorizontalController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            children: [
              // 网格层（在表头内容下面）
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GridPainter(
                        columnWidths: widget.controller.columnWidths,
                        rowHeight: widget.headerHeight,
                        rowCount: 1,
                        borderColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderWidth: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              // 表头内容（最上层，接收点击事件）
              Row(
                children: [
                  for (int i = 0; i < widget.controller.columns.length; i++)
                    _buildHeaderCell(context, widget.controller.columns[i], i),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建表头单元格
  Widget _buildHeaderCell(BuildContext context, DataGridColumn column, int index) {
    final width = widget.controller.columnWidths[index];

    return SizedBox(
      width: width,
      height: widget.headerHeight,
      child: Stack(
        children: [
          // 表头内容
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall),
            child: column.contentBuilder(context),
          ),
          // 拖动手柄
          if (index < widget.controller.columns.length)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _ResizeHandle(
                column: column,
                currentWidth: width,
                onResize: (delta) {
                  final newWidth = (width + delta).clamp(
                    column.size.minWidth ?? 50.0,
                    column.size.maxWidth ?? double.infinity,
                  );
                  _updateColumnWidth(index, newWidth);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 构建数据主体
  Widget _buildBody(BuildContext context) {
    return Scrollbar(
      controller: _bodyHorizontalController,
      thumbVisibility: false,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: false,
        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          controller: _bodyHorizontalController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: _calculateTotalWidth(),
            height: _calculateTotalHeight(),
            child: SingleChildScrollView(
              controller: _verticalController,
              physics: const ClampingScrollPhysics(),
              child: Stack(
                children: [
                  // 状态层（选中状态的背景和边框）
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SelectionLayerPainter(
                          controller: widget.controller,
                          rowHeight: widget.rowHeight,
                          columnWidths: widget.controller.columnWidths,
                          colorScheme: Theme.of(context).colorScheme,
                          borderWidth: 1,
                        ),
                      ),
                    ),
                  ),
                  // 网格层（不拦截点击事件）
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: GridPainter(
                            columnWidths: widget.controller.columnWidths,
                            rowHeight: widget.rowHeight,
                            rowCount: widget.controller.rows.length,
                            borderColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                            borderWidth: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 数据内容层（最上层，接收点击事件）
                  Column(
                    children: [
                      for (int i = 0; i < widget.controller.rows.length; i++) _buildDataRow(context, i),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建单行数据
  Widget _buildDataRow(BuildContext context, int rowIndex) {
    return SizedBox(
      height: widget.rowHeight,
      child: Row(
        children: [
          for (int j = 0; j < widget.controller.columns.length; j++)
            _buildCell(context, Postion(rowIndex: rowIndex, columnIndex: j)),
        ],
      ),
    );
  }

  /// 构建单元格
  Widget _buildCell(BuildContext context, Postion postion) {
    final width = widget.controller.columnWidths[postion.columnIndex];
    final cell = widget.controller.rows[postion.rowIndex].cells[postion.columnIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.controller.updateSelectedCell(postion);
        widget.onCellTap?.call(postion);
      },
      onDoubleTap: () {
        widget.controller.updateSelectedCell(postion);
        widget.onCellDoubleTap?.call(postion);
      },
      child: Container(
        width: width,
        height: widget.rowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: kSpacingSmall),
        child: Text(
          cell.data,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// 选中状态层绘制器
class _SelectionLayerPainter extends CustomPainter {
  final DataGridController controller;
  final double rowHeight;
  final List<double> columnWidths;
  final ColorScheme colorScheme;
  final double borderWidth;

  _SelectionLayerPainter({
    required this.controller,
    required this.rowHeight,
    required this.columnWidths,
    required this.colorScheme,
    required this.borderWidth,
  }) : super(repaint: controller.selectedCellPositionNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final selectedPosition = controller.selectedCellPostion;
    if (selectedPosition == null) return;

    final selectedRowIndex = selectedPosition.rowIndex;
    final selectedColumnIndex = selectedPosition.columnIndex;

    // 计算选中行的Y坐标
    final rowY = selectedRowIndex * rowHeight;

    // 计算选中单元格的X坐标和宽度
    double cellX = 0;
    for (int i = 0; i < selectedColumnIndex; i++) {
      cellX += columnWidths[i];
    }
    final cellWidth = columnWidths[selectedColumnIndex];

    // 计算总宽度（所有列宽之和）
    final totalWidth = columnWidths.fold(0.0, (sum, width) => sum + width);
    // 绘制选中行的背景色
    final rowBackgroundPaint = Paint()
      ..color = colorScheme.surfaceContainerLow
      ..style = PaintingStyle.fill;

    final rowBackgroundRect = Rect.fromLTWH(0, rowY, totalWidth, rowHeight);
    canvas.drawRect(rowBackgroundRect, rowBackgroundPaint);

    // 绘制选中单元格的内边框
    final selectedBorderPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;

    final selectedCellRect = Rect.fromLTWH(
      cellX + borderWidth,
      rowY + borderWidth,
      cellWidth - borderWidth * 2,
      rowHeight - borderWidth * 2,
    );
    canvas.drawRect(selectedCellRect, selectedBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionLayerPainter oldDelegate) {
    // 由于通过 repaint 参数监听 selectedCellPositionNotifier，
    // 选中状态变化会自动触发重绘，这里只需要检查其他属性的变化
    return rowHeight != oldDelegate.rowHeight ||
        columnWidths != oldDelegate.columnWidths ||
        colorScheme != oldDelegate.colorScheme ||
        borderWidth != oldDelegate.borderWidth;
  }
}

/// 自绘网格绘制器
/// 用于绘制完整的网格线，行距固定，列宽参考表格组件的列宽配置
class GridPainter extends CustomPainter {
  /// 列宽列表，来自表格组件的 columnWidths
  final List<double> columnWidths;

  /// 行高（固定行距）
  final double rowHeight;

  /// 总行数
  final int rowCount;

  /// 边框颜色
  final Color borderColor;

  /// 边框宽度
  final double borderWidth;

  GridPainter({
    required this.columnWidths,
    required this.rowHeight,
    required this.rowCount,
    this.borderColor = const Color(0xFFE0E0E0),
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (columnWidths.isEmpty || rowCount <= 0) return;

    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // 关闭抗锯齿，保证线条粗细一致

    // 计算总宽度（所有列宽之和）
    final totalWidth = columnWidths.fold(0.0, (sum, width) => sum + width);
    final totalHeight = rowCount * rowHeight;

    // 绘制垂直网格线（列分隔线）
    double x = 0;

    // 绘制列之间的分隔线
    for (int i = 0; i < columnWidths.length; i++) {
      x += columnWidths[i];
      canvas.drawLine(Offset(x, 0), Offset(x, totalHeight), paint);
    }

    // 绘制水平网格线（行分隔线）
    for (int i = 0; i < rowCount; i++) {
      final y = (i + 1) * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(totalWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    // 深度比较列宽列表
    if (columnWidths.length != oldDelegate.columnWidths.length) {
      return true;
    }
    for (int i = 0; i < columnWidths.length; i++) {
      if (columnWidths[i] != oldDelegate.columnWidths[i]) {
        return true;
      }
    }
    return rowHeight != oldDelegate.rowHeight ||
        rowCount != oldDelegate.rowCount ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth;
  }
}

/// 列宽调整手柄
class _ResizeHandle extends StatefulWidget {
  final DataGridColumn column;
  final double currentWidth;
  final ValueChanged<double> onResize;

  const _ResizeHandle({
    required this.column,
    required this.currentWidth,
    required this.onResize,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  double? _dragStartX;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          _dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          if (_dragStartX != null) {
            final delta = details.globalPosition.dx - _dragStartX!;
            widget.onResize(delta);
            _dragStartX = details.globalPosition.dx;
          }
        },
        onHorizontalDragEnd: (_) {
          _dragStartX = null;
        },
        child: Container(
          width: 8.0,
          color: Colors.transparent,
        ),
      ),
    );
  }
}
