import 'dart:ui';

import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final launcherStateProvider = FutureProvider<LauncherState>((ref) async {
  return await LauncherStorage.loadState();
});

final dockAppsProvider = Provider<List<DockItem>>((ref) {
  final state = ref.watch(launcherStateProvider).asData?.value;
  return state?.dockItems ?? LauncherStorage.defaultDockApps;
});
