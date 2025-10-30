
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/widgets/draggable_icon.dart';

class DragController {
  Application? draggedApp;
  Offset? dragPosition;
  Offset? originalPosition;
  bool isDragging = false;
  final _dragOverlayKey = GlobalKey<DraggableIconOverlayState>();
  DraggableIconOverlay? _dragOverlayWidget;
  OverlayEntry? dragOverlayEntry;
  Point<int>? _dropTarget;

  OverlayEntry? startDrag(Offset initialPosition, Rect? iconBounds, Size tileSize) {
    if (isDragging || draggedApp == null) return null;
    isDragging = true;
    originalPosition = initialPosition;
    dragPosition = initialPosition;
    _dragOverlayWidget = DraggableIconOverlay(
      key: _dragOverlayKey,
      app: draggedApp!,
      position: initialPosition,
      iconBounds: iconBounds ?? Rect.fromLTRB(0, 0, 0, 0),
      tileSize: tileSize,
    );
    dragOverlayEntry = OverlayEntry(builder: (context) => _dragOverlayWidget!);
    return dragOverlayEntry;
  }

  bool isDraggingApp(Application app) {
    return app.name == draggedApp?.name && isDragging;
  }

  bool isDropTarget(ScreenItem item) {
    return _dropTarget != null && _dropTarget!.x == item.row && _dropTarget!.y == item.col;
  }

  void updateDragPosition(Offset position, Point<int> cell) {
    if (!isDragging) return;
    dragPosition = position;
    _dropTarget = cell;
    _dragOverlayKey.currentState?.updatePosition(position);
  }

  DragChange endDrag(Offset dropPosition, List<ScreenItem> currentItems, Point<int> cell) {
    if (!isDragging || draggedApp == null) return DragChange(items: currentItems, needsSaving: false);;
    bool needsSaving = false;
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
        needsSaving = true;
      }
    } else {
      _cancelDrag();
      return DragChange(items: currentItems, needsSaving: false);
    }
    _cleanup();
    return DragChange(items: currentItems, needsSaving: needsSaving);
  }

  void _cancelDrag() {
    if (originalPosition == null) return;
    dragPosition = originalPosition;
    Future.delayed(const Duration(milliseconds: 200), _cleanup);
  }

  void _cleanup() {
    dragOverlayEntry?.remove();
    draggedApp = null;
    dragPosition = null;
    originalPosition = null;
    isDragging = false;
    _dropTarget = null;
    dragOverlayEntry = null;
  }
}

class DragChange {
  List<ScreenItem> items;
  bool needsSaving;
  DragChange({required this.items, required this.needsSaving});
}