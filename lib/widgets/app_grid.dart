import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/utils/grid_utils.dart';
import 'package:oxlauncher/widgets/app_tile.dart';
import 'package:oxlauncher/widgets/context_menu.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:oxlauncher/utils/constants.dart';

class AppGrid extends StatefulWidget {
  final List<ScreenItem> items;
  final Future<void> Function(List<ScreenItem> newItems) onReorder;

  const AppGrid({
    super.key,
    required this.items,
    required this.onReorder,
  });

  @override
  State<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<AppGrid> {
  final GlobalKey _gridKey = GlobalKey();
  late List<ScreenItem> currentItems;
  Application? _draggedApp;
  final _dragPosition = ValueNotifier<Offset?>(null);
  OverlayEntry? _menuOverlayEntry;
  OverlayEntry? _dragOverlayEntry;
  bool _isDragging = false;
  double _iconScale = 1.0;
  double _menuOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    currentItems = widget.items;
  }

  @override
  void dispose() {
    _menuOverlayEntry?.remove();
    _dragOverlayEntry?.remove();
    _dragPosition.dispose();
    super.dispose();
  }

  void _showContextMenu(Application app, Offset globalPosition) {
    _draggedApp = app;
    final iconBounds = _getIconBoundsFromPosition(globalPosition);
    if (iconBounds == null) return;

    // Create an opacity controller for the menu
    final menuOpacity = ValueNotifier<double>(0.0);

    _menuOverlayEntry = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<double>(
          valueListenable: menuOpacity,
          builder: (context, opacity, child) {
            if (opacity <= 0 && !_isDragging) return const SizedBox();
            return ContextMenu(
              iconBounds: iconBounds,
              onRemove: () => _handleMenuAction('remove'),
              onInfo: () => _handleMenuAction('info'),
              opacity: opacity,
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_menuOverlayEntry!);

    // Animate menu in
    menuOpacity.value = 1.0;

    // Handle icon scale separately (you already have this working)
    setState(() { _iconScale = 0.8; });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isDragging) {
        setState(() { _iconScale = 1.0; });
      }
    });
  }

  void _startDrag(Offset initialPosition) {
    if (_isDragging) return;

    _isDragging = true;
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
    setState(() { _iconScale = 1.0; });

    _dragPosition.value = initialPosition;
    _dragOverlayEntry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<Offset?>(
        valueListenable: _dragPosition,
        builder: (context, position, child) {
          if (position == null || _draggedApp == null) return const SizedBox();
          final iconSize = MediaQuery.sizeOf(context).shortestSide * kIconScale * 1.2;
          return Positioned(
            left: position.dx - iconSize / 2,
            top: position.dy - iconSize / 2,
            child: Container(
              width: iconSize,
              height: iconSize,
              color: Colors.transparent,
              child: Image.asset(
                'assets/images/iconpack-pixel/${_draggedApp!.iconPath}',
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
    Overlay.of(context).insert(_dragOverlayEntry!);
  }

  void _handleMenuAction(String action) {
    _cleanup();
    // TODO: implement action
    print('Menu action: $action');
  }

  void _endDrag(Offset dropPosition) {
    _cleanup();
    final cell = _getCellFromGlobalPosition(dropPosition);
    print('DROPPED at → row: ${cell.x}, col: ${cell.y}');
    // TODO: reorder logic using cell.x, cell.y
  }

  Point<int> _getCellFromGlobalPosition(Offset globalPosition) {
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) return const Point(0, 0);

    final gridBox = gridContext.findRenderObject() as RenderBox;
    if (!gridBox.hasSize) return const Point(0, 0);

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final localPos = globalPosition - gridRect.topLeft;

    final metrics = GridMetrics(
      gridSize: gridRect.size,
      numRows: kNumRows,
      numCols: kNumCols,
    );
    return metrics.getCellFromPosition(localPos);
  }

  Rect? _getIconBoundsFromPosition(Offset globalPosition) {
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) return null;

    final gridBox = gridContext.findRenderObject() as RenderBox;
    if (!gridBox.hasSize) return null;

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final localPos = globalPosition - gridRect.topLeft;

    // Get cell
    final col = (localPos.dx / gridRect.width * kNumCols).floor().clamp(0, kNumCols - 1);
    final row = (localPos.dy / gridRect.height * kNumRows).floor().clamp(0, kNumRows - 1);

    // Recreate icon bounds (must match your layout)
    final itemWidth = gridRect.width / kNumCols;
    final itemHeight = gridRect.height / kNumRows;
    final centerX = gridRect.width * (2 * col + 1) / (2 * kNumCols);
    final centerY = gridRect.height * (2 * row + 1) / (2 * kNumRows);

    final iconSize = itemWidth * 0.8; // adjust to match your visual icon size
    return Rect.fromCenter(
      center: Offset(gridRect.left + centerX, gridRect.top + centerY),
      width: iconSize,
      height: iconSize,
    );
  }

  void _cleanup() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
    _dragOverlayEntry?.remove();
    _dragOverlayEntry = null;
    _draggedApp = null;
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        if (_menuOverlayEntry != null && !_isDragging) {
          _startDrag(event.position);
        } else if (_isDragging) {
          _dragPosition.value = event.position;
        }
      },
      onPointerUp: (event) {
        if (_isDragging) {
          _endDrag(event.position);
        }
        _cleanup();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemSize = (constraints.maxWidth - 48) / kNumCols;
          return Column(
            key: _gridKey,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(kNumRows, (row) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(kNumCols, (col) {
                  final app = getAppAt(items: currentItems, row: row, col: col);
                  if (app.name.isEmpty) {
                    return const SizedBox();
                  }
                  return GestureDetector(
                    onLongPressStart: (details) {
                      _showContextMenu(app, details.globalPosition);
                    },
                    child: SizedBox(
                      width: itemSize,
                      child: AnimatedScale(
                        scale: _draggedApp?.name == app.name ? _iconScale : 1.0,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeInOut,
                        child: AppTile(app: app),
                      ),
                    ),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }
}