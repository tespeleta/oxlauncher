import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/widgets/app_tile.dart';

class Dock extends StatelessWidget {
  final List<Application> dockApps;

  const Dock({
    super.key,
    required this.dockApps
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = (MediaQuery.sizeOf(context).width - 8) / 5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dockApps.map((app) {
            return SizedBox(
              width: tileSize,
              child: AppTile(app: app, showLabel: false, tileSize: Size(tileSize, tileSize)),
            );
          }).toList(),
        ),
      ),
    );
  }
}