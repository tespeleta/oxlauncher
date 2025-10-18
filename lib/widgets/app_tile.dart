import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';

class AppTile extends StatelessWidget {
  final Application app;
  final bool showLabel;
  final double scale;
  final Size tileSize;

  const AppTile({
    super.key,
    required this.app,
    required this.tileSize,
    this.showLabel = true,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = tileSize.width * 0.7 * scale;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: tileSize.width,
        height: tileSize.height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              color: Colors.transparent,
              child: Image.asset(
                'assets/images/iconpack-pixel/${app.iconPath}',
                fit: BoxFit.cover,
              ),
            ),
            if (showLabel) const SizedBox(height: 4),
            if (showLabel)
              Flexible(
                child: Text(
                  app.name,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}