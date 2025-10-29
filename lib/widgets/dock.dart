import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/widgets/app_tile.dart';

import 'app_grid.dart';

class Dock extends StatelessWidget {
  final List<DockItem> dockItems;

  const Dock({
    super.key,
    required this.dockItems,
  });

  @override
  Widget build(BuildContext context) {
    final gridItems = dockToGridItems(dockItems);

    return SizedBox(
      height: 90,
      child: AppGrid(
        numRows: 1,
        items: gridItems,
        onReorder: (newItems) async {}
      ),
    );
  }
}