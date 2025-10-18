import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/utils/constants.dart';

class AppTile extends StatelessWidget {
  final Application app;
  final bool showLabel;
  final double scale; // ← new

  const AppTile({
    super.key,
    required this.app,
    this.showLabel = true,
    this.scale = 1.0, // default: full size
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.sizeOf(context).shortestSide * kIconScale * scale;
    return Transform.scale(
      scale: scale,
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
    );
  }
}