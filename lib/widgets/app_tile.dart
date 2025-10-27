import 'dart:io';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:svg_provider/svg_provider.dart';

const double imgSize = 192;

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
              child: _resolveImage(app),
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

var unknownImg = Image(
  width: imgSize,
  height: imgSize,
  image: SvgProvider('assets/images/unknown.svg', source: SvgSource.asset),
);

Widget _resolveImage(Application app) {
  if (app.iconPath.isEmpty) {
    return unknownImg;
  }
  var filePath = File(app.iconPath);
  if (app.iconPath.endsWith('.png')) {
    try {
      return _makeCircle(Image.file(filePath));
    } catch (_) {
    }
  }
  if (app.iconPath.endsWith('.svg')) {
    return _makeCircle(Image(
      width: imgSize,
      height: imgSize,
      image: SvgProvider(
        app.iconPath,
        source: SvgSource.file,
      ),
    ));
  }
  return unknownImg;
}

Widget _makeCircle(Widget img) {
  return Container(
    width: imgSize,
    height: imgSize,
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
    ),
    child: img,
  );
}
