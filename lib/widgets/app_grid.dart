import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:oxlauncher/utils/constants.dart';
import 'package:oxlauncher/utils/grid_utils.dart';
import 'package:oxlauncher/widgets/app_tile.dart';
import 'package:oxlauncher/widgets/context_menu.dart';

import 'draggable_icon.dart';

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
  Application? draggedApp;
  Offset? dragPosition;
  Offset? originalPosition;
  double iconScale = 1.0;
  bool isDragging = false;
  final _dragOverlayKey = GlobalKey<DraggableIconOverlayState>();
  DraggableIconOverlay? _dragOverlayWidget;
  OverlayEntry? dragOverlayEntry;
  OverlayEntry? menuOverlayEntry;
  OverlayEntry? menuBarrierEntry;
  Application? _tappedApp;
  Point<int>? _dropTarget;

  // Cache icon positions to avoid re-computation
  Map<String, Offset> _iconPositions = {};

  @override
  void initState() {
    super.initState();
    currentItems = widget.items;
    _updateIconPositions(const Size(400, 700)); // placeholder
  }

  void _updateIconPositions(Size fullSize) {
    // Add padding (e.g., 16px on each side)
    const padding = kLateralPadding;
    final gridSize = Size(
      fullSize.width - 2 * padding,
      fullSize.height - 2 * padding,
    );
    final offset = Offset(padding, padding);

    final positions = <String, Offset>{};
    for (int row = 0; row < kNumRows; row++) {
      for (int col = 0; col < kNumCols; col++) {
        final app = getAppAt(items: currentItems, row: row, col: col);
        if (app == null || app.name.isEmpty) continue;

        final centerX = offset.dx + gridSize.width * (2 * col + 1) / (2 * kNumCols);
        final centerY = offset.dy + gridSize.height * (2 * row + 1) / (2 * kNumRows);
        positions[app.name] = Offset(centerX, centerY);
      }
    }
    _iconPositions = positions;
  }

  Point<int> _getCellFromLocalPosition(Offset localPosition, Size gridSize) {
    final col = (localPosition.dx / gridSize.width * kNumCols).floor().clamp(0, kNumCols - 1);
    final row = (localPosition.dy / gridSize.height * kNumRows).floor().clamp(0, kNumRows - 1);
    return Point(row, col);
  }

  Rect? _getIconBoundsByPosition(Offset globalPosition, Size gridSize) {
    // Convert global → local
    final localPos = globalPosition;
    final col = (localPos.dx / gridSize.width * kNumCols).floor().clamp(0, kNumCols - 1);
    final row = (localPos.dy / gridSize.height * kNumRows).floor().clamp(0, kNumRows - 1);

    final itemWidth = gridSize.width / kNumCols;
    final centerX = gridSize.width * (2 * col + 1) / (2 * kNumCols);
    final centerY = gridSize.height * (2 * row + 1) / (2 * kNumRows);

    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: itemWidth * 0.8,
      height: itemWidth * 0.8,
    );
  }

  Rect _getIconBoundsByApplication(Application app, Size fullSize) {
    final position = _iconPositions[app.name];
    if (position == null) {
      // Fallback
      return Rect.fromCenter(center: Offset.zero, width: 48, height: 48);
    }

    // Compute tile size
    final tileWidth = fullSize.width / kNumCols;
    final tileHeight = fullSize.height / kNumRows;

    // Icon = 70% of tile width, centered in tile
    final iconSize = tileWidth * 0.7;
    final iconLeft = position.dx - iconSize / 2;
    final iconTop = position.dy - iconSize / 2 - (tileHeight * 0.09); // shift up to account for label

    return Rect.fromLTWH(iconLeft, iconTop, iconSize, iconSize);
  }

  void _showContextMenu(Application app, Offset globalPosition, Size fullSize) {
    _cleanupMenu();

    // Add barrier
    menuBarrierEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _cleanupMenu, // close on tap anywhere
        child: Container(color: Colors.transparent),
      ),
    );
    Overlay.of(context).insert(menuBarrierEntry!);

    draggedApp = app;

    // Get grid's RenderBox to compute local position
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) return;

    final gridBox = gridContext.findRenderObject() as RenderBox?;
    if (gridBox == null || !gridBox.hasSize) return;

    // Convert global position to grid-local
    final gridGlobalOrigin = gridBox.localToGlobal(Offset.zero);
    final localPosition = globalPosition - gridGlobalOrigin;

    // Compute icon bounds in grid-local coordinates
    final iconBoundsLocal = _getIconBoundsByPosition(localPosition, fullSize);
    if (iconBoundsLocal == null) return;

    // Convert icon bounds to global coordinates for Overlay
    final iconBounds = _getIconBoundsByApplication(app, fullSize);
    final iconGlobalBounds = Rect.fromLTWH(
      gridGlobalOrigin.dx + iconBounds.left,
      gridGlobalOrigin.dy + iconBounds.top,
      iconBounds.width,
      iconBounds.height,
    );

    menuOverlayEntry = OverlayEntry(
      builder: (context) => ContextMenu(
        iconBounds: iconGlobalBounds,
        onRemove: () => _handleMenuAction('remove'),
        onInfo: () => _handleMenuAction('info'),
      ),
    );
    Overlay.of(context).insert(menuOverlayEntry!);
  }

  void _handleMenuAction(String action) {
    _cleanupMenu();
    // TODO
  }

  void _startDrag(Offset initialPosition, Rect? iconBounds, Size tileSize) {
    if (isDragging || draggedApp == null) return;
    isDragging = true;
    menuOverlayEntry?.remove();
    menuOverlayEntry = null;
    originalPosition = initialPosition;
    setState(() {
      dragPosition = initialPosition;
    });
    _dragOverlayWidget = DraggableIconOverlay(
      key: _dragOverlayKey,
      app: draggedApp!,
      position: initialPosition,
      iconBounds: iconBounds ?? Rect.fromLTRB(0, 0, 0, 0),
      tileSize: tileSize,
    );
    dragOverlayEntry = OverlayEntry(builder: (context) => _dragOverlayWidget!);
    Overlay.of(context).insert(dragOverlayEntry!);
  }

  void _updateDragPosition(Offset position, Size gridSize) {
    if (!isDragging) return;
    final cell = _getCellFromLocalPosition(position, gridSize);
    setState(() {
      dragPosition = position;
      _dropTarget = cell;
    });
    _dragOverlayKey.currentState?.updatePosition(position);
  }

  void _endDrag(Offset dropPosition, Size gridSize) {
    if (!isDragging || draggedApp == null) return;

    final cell = _getCellFromLocalPosition(dropPosition, gridSize);
    final toIndex = currentItems.indexWhere(
          (item) => item.row == cell.x && item.col == cell.y,
    );

    if (toIndex != -1) {
      final fromIndex = currentItems.indexWhere(
            (item) => (item.app?.name == draggedApp!.name),
      );
      if (fromIndex != -1 && fromIndex != toIndex) {
        final fromItem = currentItems[fromIndex];
        final toItem = currentItems[toIndex];
        setState(() {
          currentItems[fromIndex] = ScreenItem(
            app: toItem.app,
            row: fromItem.row,
            col: fromItem.col,
          );
          currentItems[toIndex] = ScreenItem(
            app: fromItem.app,
            row: cell.x,
            col: cell.y,
          );
        });
        widget.onReorder(currentItems);
        _updateIconPositions(gridSize);
      }
    } else {
      _cancelDrag();
      return;
    }
    _cleanup();
  }

  void _cancelDrag() {
    if (originalPosition == null) return;
    setState(() {
      dragPosition = originalPosition;
    });
    Future.delayed(const Duration(milliseconds: 200), _cleanup);
  }

  void _cleanup() {
    _cleanupMenu();
    dragOverlayEntry?.remove();
    setState(() {
      draggedApp = null;
      dragPosition = null;
      originalPosition = null;
      isDragging = false;
      _tappedApp = null;
      _dropTarget = null;
      dragOverlayEntry = null;
    });
  }

  void _cleanupMenu() {
    menuBarrierEntry?.remove();
    menuBarrierEntry = null;
    menuOverlayEntry?.remove();
    menuOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 0.9 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridSize = Size(constraints.maxWidth, constraints.maxHeight);
          final tileWidth = gridSize.width / kNumCols;
          final tileHeight = gridSize.height / kNumRows;
          final fullSize = constraints.biggest;
          _updateIconPositions(fullSize);

          return Listener(
            onPointerMove: (event) {
              final tileSize = Size(tileWidth, tileHeight);
              if (menuOverlayEntry != null && !isDragging) {
                var iconPos = _getIconBoundsByPosition(event.position, gridSize);
                _startDrag(event.position, iconPos, tileSize);
              } else if (isDragging) {
                _updateDragPosition(event.position, gridSize);
              }
            },
            onPointerUp: (event) {
              if (isDragging) {
                _endDrag(event.position, gridSize);
              }
            },
            child: SizedBox.fromSize(
              size: gridSize,
              child: Stack(
                key: _gridKey,
                children: [
                  // All icons as Positioned widgets
                  for (final item in currentItems)
                    if (item.app != null && item.app!.name.isNotEmpty)
                      _buildIcon(item.app!, gridSize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(Application app, Size gridSize) {
    final position = _iconPositions[app.name];
    if (position == null) return const SizedBox();

    if (app.name == draggedApp?.name && isDragging) {
      return const SizedBox();
    }

    // Compute tile size from grid
    final tileWidth = gridSize.width / kNumCols;
    final tileHeight = gridSize.height / kNumRows;

    // Check if this icon is the drop target
    final item = currentItems.firstWhere((i) => (i.app != null && i.app!.name == app.name),
      orElse: () => throw StateError('App not found in grid'),
    );
    final isDropTarget = _dropTarget != null &&
        _dropTarget!.x == item.row &&
        _dropTarget!.y == item.col;
    final iconBounds = withPadding(_getIconBoundsByApplication(app, gridSize), 4);

    return Positioned(
      left: position.dx - tileWidth / 2,
      top: position.dy - tileHeight / 2,
      child: GestureDetector(
        onTapDown: (_) {
          if (!isDragging && menuOverlayEntry == null) {
            setState(() {
              _tappedApp = app;
              iconScale = 0.8;
            });
          }
        },
        onTapUp: (_) {
          setState(() {
            iconScale = 1;
          });
          // TODO: launch app
        },
        onPanStart: (_) {
          // Cancel tap feedback — this is a drag gesture
          if (_tappedApp == app) {
            setState(() {
              _tappedApp = null;
            });
          }
        },
        onLongPressStart: (details) {
          setState(() {
            iconScale = 1.1;
          });
          _showContextMenu(app, details.globalPosition, gridSize);
        },
        onLongPressEnd: (details) {
          setState(() {
            iconScale = 1;
          });
        },
        child: SizedBox(
          width: tileWidth,
          height: tileHeight,

          child: Stack(
            children: [
              // Highlight (only icon area)
              if (isDropTarget)
                Positioned(
                  left: iconBounds.left - (position.dx - tileWidth / 2),
                  top: iconBounds.top - (position.dy - tileHeight / 2),
                  child: Container(
                    width: iconBounds.width,
                    height: iconBounds.height,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              // AppTile
              Center(
                child: AnimatedScale(
                  scale: _tappedApp?.name == app.name ? iconScale : 1,
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeInOut,
                  child: AppTile(
                    app: app,
                    tileSize: Size(tileWidth, tileHeight),
                    showLabel: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
