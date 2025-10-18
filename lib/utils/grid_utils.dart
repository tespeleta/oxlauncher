import 'dart:math';

import 'package:flutter/material.dart';

class GridMetrics {
  final Size gridSize;
  final int numRows;
  final int numCols;

  GridMetrics({
    required this.gridSize,
    required this.numRows,
    required this.numCols,
  });

  Rect getIconBounds(int row, int col) {
    // Recreate layout: spaceEvenly centers at (2i+1)/(2N)
    final itemWidth = gridSize.width / numCols;
    final itemHeight = gridSize.height / numRows;

    final centerX = gridSize.width * (2 * col + 1) / (2 * numCols);
    final centerY = gridSize.height * (2 * row + 1) / (2 * numRows);

    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: itemWidth * 0.8, // or your actual icon size
      height: itemWidth * 0.8,
    );
  }

  Point<int> getCellFromPosition(Offset localPosition) {
    final col = (localPosition.dx / gridSize.width * numCols).floor().clamp(0, numCols - 1);
    final row = (localPosition.dy / gridSize.height * numRows).floor().clamp(0, numRows - 1);
    return Point(row, col);
  }
}