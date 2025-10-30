import 'package:flutter/material.dart';
import 'package:oxlauncher/controllers/drag_controller.dart';
import 'package:oxlauncher/model/model.dart';

import 'app_grid.dart';

class Dock extends StatelessWidget {
  final List<ScreenItem> items;
  final DragController dragController;
  final Future<Null> Function(dynamic newItems) onChange;

  const Dock({
    super.key,
    required this.items,
    required this.dragController,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: AppGrid(
        numRows: 1,
        showLabels: false,
        items: items,
        dragController: dragController,
        onChange: onChange,
      ),
    );
  }
}
