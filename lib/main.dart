import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oxlauncher/utils/grid_utils.dart';
import 'package:oxlauncher/widgets/context_menu.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';

void main() => runApp(const ProviderScope(child: OxygenLauncher()));

const int kNumRows = 5;
const int kNumCols = 5;
const double kIconScale = 0.125;

class OxygenLauncher extends ConsumerWidget {
  const OxygenLauncher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(launcherStateProvider);

    return MaterialApp(
      home: stateAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (state) {
          final currentScreen = state.screens.first; // only 1 screen for now
          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  // Wallpaper
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/default_wallpaper.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Slight gradient on top
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      // Grid: use currentScreen.items
                      Expanded(
                        child: GestureDetector(
                          child: _AppGrid(
                            items: currentScreen.items,
                            onReorder: (newItems) async {
                              print('_reordered ${newItems.length} items');
                              // Optional: save to disk
                              // final updatedState = LauncherState(
                              //   screens: [LauncherScreen(items: newItems)],
                              //   dockApps: state.dockApps,
                              // );
                              // await LauncherStorage.saveState(updatedState);
                              // Optional: refresh UI (if you later add more screens or need sync)
                              // ref.refresh(launcherStateProvider);
                            },
                          ),
                        ),
                      ),
                      // Dock
                      _Dock(dockApps: state.dockApps)
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

class _AppTile extends StatelessWidget {
  final Application app;
  final bool showLabel;
  final double scale; // ← new

  const _AppTile({
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

class _AppGrid extends StatefulWidget {
  final List<ScreenItem> items;
  final Future<void> Function(List<ScreenItem> newItems) onReorder;

  const _AppGrid({
    required this.items,
    required this.onReorder,
  });

  @override
  State<_AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<_AppGrid> {
  final GlobalKey _gridKey = GlobalKey();
  late List<ScreenItem> currentItems;
  Application? _draggedApp;
  final _dragPosition = ValueNotifier<Offset?>(null);
  OverlayEntry? _menuOverlayEntry;
  OverlayEntry? _dragOverlayEntry;
  bool _isDragging = false;
  double _iconScale = 1.0;

  @override
  void initState() {
    super.initState();
    currentItems = widget.items;
  }

  @override
  void dispose() {
    _menuOverlayEntry?.remove();
    _dragOverlayEntry?.remove();
    _dragPosition.dispose();
    super.dispose();
  }

void _showContextMenu(Application app, Offset globalPosition) {
  _draggedApp = app;
  setState(() { _iconScale = 0.8; });

  final iconBounds = _getIconBoundsFromPosition(globalPosition);
  if (iconBounds == null) return;

  _menuOverlayEntry = OverlayEntry(
    builder: (context) => ContextMenu(
      iconBounds: iconBounds, // pass bounds instead of position
      onRemove: () => _handleMenuAction('remove'),
      onInfo: () => _handleMenuAction('info'),
    ),
  );
  Overlay.of(context).insert(_menuOverlayEntry!);

  Future.delayed(const Duration(milliseconds: 100), () {
    if (!_isDragging) {
      setState(() { _iconScale = 1.0; });
    }
  });
}

  void _startDrag(Offset initialPosition) {
    if (_isDragging) return;

    _isDragging = true;
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
    setState(() { _iconScale = 1.0; });

    _dragPosition.value = initialPosition;
    _dragOverlayEntry = OverlayEntry(
      builder: (context) => ValueListenableBuilder<Offset?>(
        valueListenable: _dragPosition,
        builder: (context, position, child) {
          if (position == null || _draggedApp == null) return const SizedBox();
          final iconSize = MediaQuery.sizeOf(context).shortestSide * kIconScale * 1.2;
          return Positioned(
            left: position.dx - iconSize / 2,
            top: position.dy - iconSize / 2,
            child: Container(
              width: iconSize,
              height: iconSize,
              color: Colors.transparent,
              child: Image.asset(
                'assets/images/iconpack-pixel/${_draggedApp!.iconPath}',
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
    Overlay.of(context).insert(_dragOverlayEntry!);
  }

  void _handleMenuAction(String action) {
    _cleanup();
    // TODO: implement action
    print('Menu action: $action');
  }

  void _endDrag(Offset dropPosition) {
    _cleanup();
    final cell = _getCellFromGlobalPosition(dropPosition);
    print('DROPPED at → row: ${cell.x}, col: ${cell.y}');
    // TODO: reorder logic using cell.x, cell.y
  }

  Point<int> _getCellFromGlobalPosition(Offset globalPosition) {
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) return const Point(0, 0);

    final gridBox = gridContext.findRenderObject() as RenderBox;
    if (!gridBox.hasSize) return const Point(0, 0);

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final localPos = globalPosition - gridRect.topLeft;

    final metrics = GridMetrics(
      gridSize: gridRect.size,
      numRows: kNumRows,
      numCols: kNumCols,
    );
    return metrics.getCellFromPosition(localPos);
  }

  Rect? _getIconBoundsFromPosition(Offset globalPosition) {
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) return null;

    final gridBox = gridContext.findRenderObject() as RenderBox;
    if (!gridBox.hasSize) return null;

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final localPos = globalPosition - gridRect.topLeft;

    // Get cell
    final col = (localPos.dx / gridRect.width * kNumCols).floor().clamp(0, kNumCols - 1);
    final row = (localPos.dy / gridRect.height * kNumRows).floor().clamp(0, kNumRows - 1);

    // Recreate icon bounds (must match your layout)
    final itemWidth = gridRect.width / kNumCols;
    final itemHeight = gridRect.height / kNumRows;
    final centerX = gridRect.width * (2 * col + 1) / (2 * kNumCols);
    final centerY = gridRect.height * (2 * row + 1) / (2 * kNumRows);

    final iconSize = itemWidth * 0.8; // adjust to match your visual icon size
    return Rect.fromCenter(
      center: Offset(gridRect.left + centerX, gridRect.top + centerY),
      width: iconSize,
      height: iconSize,
    );
  }

  void _cleanup() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
    _dragOverlayEntry?.remove();
    _dragOverlayEntry = null;
    _draggedApp = null;
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        if (_menuOverlayEntry != null && !_isDragging) {
          _startDrag(event.position);
        } else if (_isDragging) {
          _dragPosition.value = event.position;
        }
      },
      onPointerUp: (event) {
        if (_isDragging) {
          _endDrag(event.position);
        }
        _cleanup();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemSize = (constraints.maxWidth - 48) / kNumCols;
          return Column(
            key: _gridKey,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(kNumRows, (row) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(kNumCols, (col) {
                  final app = getAppAt(items: currentItems, row: row, col: col);
                  if (app.name.isEmpty) {
                    return const SizedBox();
                  }
                  return GestureDetector(
                    onLongPressStart: (details) {
                      _showContextMenu(app, details.globalPosition);
                    },
                    child: SizedBox(
                      width: itemSize,
                      child: Transform.scale(
                        scale: _draggedApp?.name == app.name ? _iconScale : 1.0,
                        child: _AppTile(app: app),
                      ),
                    ),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  final List<Application> dockApps;
  const _Dock({required this.dockApps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dockApps.map((app) {
            return SizedBox(
              width: (MediaQuery.sizeOf(context).width - 8) / 5,
              child: _AppTile(app: app, showLabel: false),
            );
          }).toList(),
        ),
      ),
    );
  }
}