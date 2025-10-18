import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:oxlauncher/utils/constants.dart';
import 'package:oxlauncher/widgets/app_tile.dart';
import 'package:oxlauncher/widgets/context_menu.dart';

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
  OverlayEntry? menuOverlayEntry;
  OverlayEntry? menuBarrierEntry;
  Application? _temporaryPressedApp;

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
        if (app.name.isEmpty) continue;

        final centerX = offset.dx + gridSize.width * (2 * col + 1) / (2 * kNumCols);
        final centerY = offset.dy + gridSize.height * (2 * row + 1) / (2 * kNumRows);
        positions[app.name] = Offset(centerX, centerY);
      }
    }
    _iconPositions = positions;
  }

  Rect? _getIconBoundsFromPosition(Offset globalPosition, Size gridSize) {
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

  Point<int> _getCellFromLocalPosition(Offset localPosition, Size gridSize) {
    final col = (localPosition.dx / gridSize.width * kNumCols).floor().clamp(0, kNumCols - 1);
    final row = (localPosition.dy / gridSize.height * kNumRows).floor().clamp(0, kNumRows - 1);
    return Point(row, col);
  }

  Rect _getIconOnlyBounds(Application app, Size fullSize) {
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
    final iconBoundsLocal = _getIconBoundsFromPosition(localPosition, fullSize);
    if (iconBoundsLocal == null) return;

    // Convert icon bounds to global coordinates for Overlay
    final iconOnlyLocal = _getIconOnlyBounds(app, fullSize);
    final iconOnlyGlobal = Rect.fromLTWH(
      gridGlobalOrigin.dx + iconOnlyLocal.left,
      gridGlobalOrigin.dy + iconOnlyLocal.top,
      iconOnlyLocal.width,
      iconOnlyLocal.height,
    );

    menuOverlayEntry = OverlayEntry(
      builder: (context) => ContextMenu(
        iconBounds: iconOnlyGlobal,
        onRemove: () => _handleMenuAction('remove'),
        onInfo: () => _handleMenuAction('info'),
      ),
    );
    Overlay.of(context).insert(menuOverlayEntry!);

    setState(() { iconScale = 1; });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isDragging) {
        setState(() { iconScale = 1.0; });
      }
    });
  }

  void _cleanupMenu() {
    menuBarrierEntry?.remove();
    menuBarrierEntry = null;
    menuOverlayEntry?.remove();
    menuOverlayEntry = null;
  }

  void _handleMenuAction(String action) {
    _cleanupMenu();
    // TODO
  }

  void _startDrag(Offset initialPosition) {
    if (isDragging || draggedApp == null) return;
    isDragging = true;
    menuOverlayEntry?.remove();
    menuOverlayEntry = null;
    originalPosition = initialPosition;
    setState(() {
      dragPosition = initialPosition;
    });
  }

  void _updateDragPosition(Offset position) {
    if (!isDragging) return;
    setState(() {
      dragPosition = position;
    });
  }

  void _endDrag(Offset dropPosition, Size gridSize) {
    if (!isDragging || draggedApp == null) return;

    final cell = _getCellFromLocalPosition(dropPosition, gridSize);
    final toIndex = currentItems.indexWhere(
          (item) => item.row == cell.x && item.col == cell.y,
    );

    if (toIndex != -1) {
      final fromIndex = currentItems.indexWhere(
            (item) => item.app.name == draggedApp!.name,
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
    setState(() {
      draggedApp = null;
      dragPosition = null;
      originalPosition = null;
      isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSize = Size(constraints.maxWidth, constraints.maxHeight);
        final tileWidth = gridSize.width / kNumCols;
        final tileHeight = gridSize.height / kNumRows;
        final fullSize = constraints.biggest;
        _updateIconPositions(fullSize);

        return Listener(
          onPointerMove: (event) {
            if (menuOverlayEntry != null && !isDragging) {
              _startDrag(event.position);
            } else if (isDragging) {
              _updateDragPosition(event.position);
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
                  if (item.app.name.isNotEmpty)
                    _buildIcon(item.app, gridSize),
                // Draggable icon (overrides static position during drag)
                if (dragPosition != null && draggedApp != null)
                  AnimatedPositioned(
                    left: dragPosition!.dx - tileWidth / 2,
                    top: dragPosition!.dy - tileHeight / 2,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: AppTile(
                        app: draggedApp!,
                        scale: 1.05,
                        showLabel: false, // no label during drag
                        tileSize: Size(tileWidth, tileHeight),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

    return Positioned(
      left: position.dx - tileWidth / 2,
      top: position.dy - tileHeight / 2,
      child: GestureDetector(
        onTapDown: (_) {
          if (!isDragging && menuOverlayEntry == null) {
            setState(() {
              _temporaryPressedApp = app;
            });
          }
        },
        onTapUp: (_) {
          if (_temporaryPressedApp == app) {
            setState(() {
              _temporaryPressedApp = null;
            });
            // TODO: launch app
          }
        },
        onLongPressStart: (details) {
          setState(() {
            _temporaryPressedApp = null; // cancel any tap feedback
          });
          _showContextMenu(app, details.globalPosition, gridSize);
        },
        child: SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: AnimatedScale(
            scale: _temporaryPressedApp?.name == app.name ? kIconPressedScale : (draggedApp?.name == app.name && isDragging ? iconScale : 1.0),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: AppTile(
              app: app,
              tileSize: Size(tileWidth, tileHeight),
              scale: app.name == draggedApp?.name ? iconScale : 1.0,
              showLabel: true,
            ),
          ),
        ),
      ),
    );
  }

}