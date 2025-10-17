import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/storage/launcher_storage.dart';
import 'package:riverpod/riverpod.dart';

final launcherStateProvider = FutureProvider<LauncherState>((ref) async {
  return await LauncherStorage.loadState();
});

final dockAppsProvider = Provider<List<Application>>((ref) {
  final state = ref.watch(launcherStateProvider).asData?.value;
  return state?.dockApps ?? LauncherStorage.defaultDockApps;
});