import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';

void main() => runApp(const ProviderScope(child: OxygenLauncher()));

const int kNumRows = 5;
const int kNumCols = 5;

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
                            Colors.black.withOpacity(0.1),
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
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
                          onTapDown: (details) {
                            print('TAP DROP: ${details.globalPosition}');
                            // Use this to test your cell math
                          },
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

  const _AppTile({required this.app, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.sizeOf(context).shortestSide * 0.125;
    return Column(
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
  OverlayState? _overlayState;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    print('[_AppGridState INIT] this: $hashCode');
    super.initState();
    currentItems = widget.items;
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _dragPosition.dispose();
    super.dispose();
  }
  void _startDrag(Application app, Offset globalPosition) {
    _draggedApp = app;
    _dragPosition.value = globalPosition; // ✅ set initial position
    _overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildDragPreview(),
    );
    _overlayState?.insert(_overlayEntry!);
  }

  Widget _buildDragPreview() {
    if (_draggedApp == null) {
      return const SizedBox();
    }
    return ValueListenableBuilder<Offset?>(
      valueListenable: _dragPosition,
      builder: (context, position, child) {
        if (position == null || _draggedApp == null) return const SizedBox();
        return Positioned(
          left: position.dx - 24,
          top: position.dy - 24,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                'assets/images/iconpack-pixel/${_draggedApp!.iconPath}',
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateDragPosition(Offset position) {
    _dragPosition.value = position; // triggers overlay rebuild
  }

  void _endDrag(Offset dropPosition) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    // Compute drop cell
    final gridContext = _gridKey.currentContext;
    if (gridContext == null) {
      setState(() { _draggedApp = null; });
      return;
    }

    final gridBox = gridContext.findRenderObject() as RenderBox;
    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final localX = dropPosition.dx - gridRect.left;
    final localY = dropPosition.dy - gridRect.top;

    int closestCol = 0;
    double minDx = double.infinity;
    for (int col = 0; col < kNumCols; col++) {
      final centerX = gridRect.width * (2 * col + 1) / (2 * kNumCols);
      final dx = (localX - centerX).abs();
      if (dx < minDx) {
        minDx = dx;
        closestCol = col;
      }
    }

    int closestRow = 0;
    double minDy = double.infinity;
    for (int row = 0; row < kNumRows; row++) {
      final centerY = gridRect.height * (2 * row + 1) / (2 * kNumRows);
      final dy = (localY - centerY).abs();
      if (dy < minDy) {
        minDy = dy;
        closestRow = row;
      }
    }

    print('DROPPED at → row: $closestRow, col: $closestCol');

    // TODO: reorder logic
    // For now: just print

    setState(() {
      _draggedApp = null;
      _dragPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) {
        print('(PointerMove) event.position: ${event.position}');
        if (_draggedApp != null) {
          print('→ Calling _updateDragPosition');
          _updateDragPosition(event.position);
        }
      },
      onPointerUp: (event) {
        print('(PointerUp) event.position: ${event.position}');
        if (_draggedApp != null) {
          _endDrag(event.position);
        }
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
                      _startDrag(app, details.globalPosition);
                    },
                    child: SizedBox(
                      width: itemSize,
                      child: Opacity(
                        opacity: _draggedApp?.name == app.name ? 0.5 : 1.0,
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