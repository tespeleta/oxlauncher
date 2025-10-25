import 'package:flutter/material.dart';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:oxlauncher/widgets/app_grid.dart';
import 'package:oxlauncher/widgets/dock.dart';

void main() => runApp(const ProviderScope(child: OxygenLauncher()));

class OxygenLauncher extends ConsumerWidget {
  const OxygenLauncher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(launcherStateProvider);

    return MaterialApp(
      home: stateAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, xx) {
          print(err);
          print(xx);
          return Scaffold(body: Center(child: Text('Error: $err')));
        },
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
                          child: AppGrid(
                            items: currentScreen.items,
                            onReorder: (newItems) async {
                              // Save to disk
                              final updatedState = LauncherState(
                                screens: [LauncherScreen(items: newItems)],
                                dockApps: state.dockApps,
                              );
                              await LauncherStorage.saveState(updatedState);
                              ref.refresh(launcherStateProvider);
                            },
                          ),
                        ),
                      ),
                      // Dock
                      Dock(dockApps: state.dockApps)
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
