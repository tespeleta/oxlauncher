import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxlauncher/controllers/drag_controller.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:oxlauncher/utils/constants.dart';
import 'package:oxlauncher/utils/grid_utils.dart';
import 'package:oxlauncher/widgets/app_tile.dart';
import 'package:oxlauncher/widgets/context_menu.dart';

class AppGrid extends StatefulWidget {
  final List<ScreenItem> items;
  final DragController dragController;
  final Future<Null> Function(dynamic newItems) onChange;
  final bool showLabels;
  final int numRows;
  final int numCols;

  const AppGrid({
    super.key,
    required this.items,
    required this.dragController,
    required this.onChange,
    this.showLabels = true,
    this.numRows = kNumRows,
    this.numCols = kNumCols,
  });

  @override
  State<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<AppGrid> {
  final GlobalKey _gridKey = GlobalKey();
  late List<ScreenItem> currentItems;
  double iconScale = 1.0;
  OverlayEntry? menuOverlayEntry;
  OverlayEntry? menuBarrierEntry;
  Application? _tappedApp;
  int _numRows = 0, _numCols = 0;

  // Cache icon positions to avoid re-computation
  Map<String, Offset> _iconPositions = {};

  @override
  void initState() {
    super.initState();
    currentItems = widget.items;
    _numCols = widget.numCols;
    _numRows = widget.numRows;
    _updateIconPositions(const Size(400, 700));
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
    for (int row = 0; row < _numRows; row++) {
      for (int col = 0; col < _numCols; col++) {
        final app = getAppAt(items: currentItems, row: row, col: col);
        if (app == null || app.name.isEmpty) continue;

        final centerX = offset.dx + gridSize.width * (2 * col + 1) / (2 * _numCols);
        final centerY = offset.dy + gridSize.height * (2 * row + 1) / (2 * _numRows);
        positions[app.name] = Offset(centerX, centerY);
      }
    }
    _iconPositions = positions;
  }

  Rect? _getIconBoundsByPosition(Offset globalPosition, Size gridSize) {
    // Convert global → local
    final localPos = globalPosition;
    final col = (localPos.dx / gridSize.width * _numCols).floor().clamp(0, _numCols - 1);
    final row = (localPos.dy / gridSize.height * _numRows).floor().clamp(0, _numRows - 1);

    final itemWidth = gridSize.width / _numCols;
    final centerX = gridSize.width * (2 * col + 1) / (2 * _numCols);
    final centerY = gridSize.height * (2 * row + 1) / (2 * _numRows);

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
    final tileWidth = fullSize.width / _numCols;
    final tileHeight = fullSize.height / _numRows;

    // Icon = 70% of tile width, centered in tile
    final spaceForLabel = tileHeight * 0.09;
    final iconSize = tileWidth * 0.7;
    final iconLeft = position.dx - iconSize / 2;
    final iconTop = position.dy - iconSize / 2 - spaceForLabel; // shift up to account for label

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

  void _cleanupMenu() {
    menuBarrierEntry?.remove();
    menuBarrierEntry = null;
    menuOverlayEntry?.remove();
    menuOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = widget.dragController.isDragging;
    return AnimatedScale(
      scale: isDragging ? 0.9 : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridSize = Size(constraints.maxWidth, constraints.maxHeight);
          final tileWidth = gridSize.width / _numCols;
          final tileHeight = gridSize.height / _numRows;
          final fullSize = constraints.biggest;

          _updateIconPositions(fullSize);
          final id = _numRows == 1 ? 'dock' : 'grid';
          return Listener(
            onPointerMove: (event) {
              final tileSize = Size(tileWidth, tileHeight);
              if (menuOverlayEntry != null && !isDragging) {
                final iconPos = _getIconBoundsByPosition(event.position, gridSize);
                final overlay = widget.dragController.startDrag(event.position, iconPos, tileSize);
                if (overlay == null) return;
                menuOverlayEntry?.remove();
                menuOverlayEntry = null;
                Overlay.of(context).insert(overlay);
                setState(() {});

              } else if (isDragging) {
                final cell = _getCellFromLocalPosition(event.position, gridSize);
                widget.dragController.updateDragPosition(event.position, cell);
                setState(() {});
              }
            },
            onPointerUp: (event) {
              if (isDragging) {
                final cell = _getCellFromLocalPosition(event.position, gridSize);
                final change = widget.dragController.endDrag(event.position, currentItems, cell);
                _cleanupMenu();
                setState(() {
                  _tappedApp = null;
                });
                if (change.needsSaving) {
                  widget.onChange(change.items);
                }
                _updateIconPositions(gridSize);
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

  Point<int> _getCellFromLocalPosition(Offset localPosition, Size gridSize) {
    final col = (localPosition.dx / gridSize.width * _numCols).floor().clamp(0, _numCols - 1);
    final row = (localPosition.dy / gridSize.height * _numRows).floor().clamp(0, _numRows - 1);
    return Point(row, col);
  }

  Widget _buildIcon(Application app, Size gridSize) {
    final position = _iconPositions[app.name];
    if (position == null) return const SizedBox();

    if (widget.dragController.isDraggingApp(app)) {
      return const SizedBox();
    }

    // Compute tile size from grid
    final tileWidth = gridSize.width / _numCols;
    final tileHeight = gridSize.height / _numRows;
    final highlightOffset = widget.showLabels ? tileHeight * 0.02 : tileHeight * 0.09;

    // Check if this icon is the drop target
    final item = currentItems.firstWhere((i) => (i.app != null && i.app!.name == app.name),
      orElse: () => throw StateError('App not found in grid'),
    );
    final iconBounds = withPadding(_getIconBoundsByApplication(app, gridSize), 4);

    return Positioned(
      left: position.dx - tileWidth / 2,
      top: position.dy - tileHeight / 2,
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.dragController.isDragging && menuOverlayEntry == null) {
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
          widget.dragController.draggedApp = app;
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
              if (widget.dragController.isDropTarget(item))
                Positioned(
                  left: iconBounds.left - (position.dx - tileWidth / 2),
                  top: iconBounds.top - (position.dy - tileHeight / 2) + highlightOffset,
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
                    showLabel: widget.showLabels,
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
