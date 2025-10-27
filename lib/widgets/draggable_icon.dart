
import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';

import 'app_tile.dart';

class DraggableIconOverlay extends StatefulWidget {
  final Offset position;
  final Rect iconBounds;
  final Application app;
  final Size tileSize;

  const DraggableIconOverlay({
    super.key,
    required this.position,
    required this.iconBounds,
    required this.app,
    required this.tileSize,
  });

  @override
  State<DraggableIconOverlay> createState() => DraggableIconOverlayState();
}

class DraggableIconOverlayState extends State<DraggableIconOverlay> {
  late Offset position = widget.position;

  void updatePosition(Offset newPos) {
    if (mounted) setState(() => position = newPos);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - widget.tileSize.width / 2,
      top: position.dy - widget.tileSize.height / 2,
      child: SizedBox(
        width: widget.tileSize.width,
        height: widget.tileSize.height,
        child: AppTile(app: widget.app, scale: 1.05, showLabel: false, tileSize: widget.tileSize),
      ),
    );
  }
}