import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:oxlauncher/model/model.dart';
import 'package:oxlauncher/utils/constants.dart';

class LauncherStorage {

  static Future<String> get configPath async {
    final configDir = _getAppDataDir();
    final file = File('$configDir/oxlauncher.json');
    await file.parent.create(recursive: true);
    return file.path;
  }

  static Future<LauncherState> loadState() async {
    final path = await configPath;
    final file = File(path);
    print(file);
    if (!file.existsSync()) {
      final defaultState = _createDefaultState(defaultDockApps);
      await saveState(defaultState);
      return defaultState;
    }
    final data = await file.readAsString();
    return LauncherState.fromJson(json.decode(data) as Map<String, dynamic>);
  }

  static Future<void> saveState(LauncherState state) async {
    final path = await configPath;
    final data = json.encode(state.toJson());
    await File(path).writeAsString(data);
  }

  /// Default state
  static LauncherState _createDefaultState(List<Application> defaultDockApps) {
    return LauncherState(
      screens: [_createDefaultScreen()],
      dockApps: defaultDockApps,
    );
  }

  static const List<Application> defaultDockApps = [
    // Application(name: 'Phone', iconPath: 'phone.png'),
    // Application(name: 'WhatsApp', iconPath: 'whatsapp.png'),
    // Application(name: 'Camera', iconPath: 'camerapro.png'),
    // Application(name: 'Mail', iconPath: 'com_google_android_gm.png'),
    // Application(name: 'Browser', iconPath: 'firefox_nightly.png'),
  ];

  static LauncherScreen _createDefaultScreen() {
    final items = <ScreenItem>[];
    var availableApps = _getAvailableApplications();
    final n = min(availableApps.length, 22);

    for (int i = 0; i < n; i++) {
      var item = ScreenItem(
        row: i ~/ 5,
        col: i % 5,
      );
      // if (i % 2 == 0) {
      item.app = availableApps[i];
      // }
      items.add(item);
    }
    return LauncherScreen(items: items);
  }
}

String _getAppDataDir() {
  final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
  final home = Platform.environment['HOME'];

  if (xdgDataHome != null) {
    return '$xdgDataHome/$kAppId';
  } else if (home != null) {
    return '$home/.local/share/$kAppId';
  } else {
    // Fallback: try to get home via shell (in case env is missing)
    // Note: This won't run synchronously, so we show a warning instead
    return '<HOME and XDG_DATA_HOME not set — cannot determine app data dir>';
  }
}

Application? getAppAt({
  required List<ScreenItem> items,
  required int row,
  required int col,
}) {
  try {
    return items.firstWhere((item) => item.row == row && item.col == col).app;
  } catch (_) {
    return null;
  }
}


/// Parse a single .desktop file and return an Application object,
/// or null if the app should not be shown in the drawer.
Application? parseDesktopFile(File file) {
  String? name;
  String? exec;
  String? icon;
  String type = 'Application'; // default type
  bool noDisplay = false;
  bool hidden = false;

  try {
    final lines = file.readAsLinesSync();
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('Name=')) name = line.substring(5);
      if (line.startsWith('Exec=')) exec = line.substring(5);
      if (line.startsWith('Icon=')) icon = line.substring(5);
      if (line.startsWith('Type=')) type = line.substring(5);
      if (line.startsWith('NoDisplay=')) noDisplay = line.substring(10).toLowerCase() == 'true';
      if (line.startsWith('Hidden=')) hidden = line.substring(7).toLowerCase() == 'true';
    }
  } catch (_) {
    return null;
  }

  // Only show visible, startable apps
  if (name == null || exec == null) return null;
  if (type != 'Application') return null;
  if (noDisplay || hidden) return null;
  if (icon == null || icon.isEmpty) return null;
  if (exec.contains('oxlauncher')) return null;

  return Application(
    name: name,
    exec: exec,
    iconPath: icon,
    desktopFilePath: file.path,
  );
}

/// Scan directories for .desktop files and return a list of visible/startable apps.
List<Application> _getAvailableApplications() {
  final apps = <Application>[];

  final paths = [
    '/usr/share/applications',
    '/home/phablet/.local/share/applications',
    '/home/phablet/.local/share/libertine-container'
  ];

  for (var path in paths) {
    final dir = Directory(path);
    if (!dir.existsSync()) continue;

    if (path.contains('libertine-container')) {
      // Scan all libertine containers
      for (var container in dir.listSync()) {
        final appsDir = Directory('${container.path}/rootfs/usr/share/applications');
        if (!appsDir.existsSync()) continue;
        for (var file in appsDir.listSync()) {
          if (file is File && file.path.endsWith('.desktop')) {
            final app = parseDesktopFile(file);
            if (app != null) apps.add(app);
          }
        }
      }
    } else {
      // Normal apps
      for (var file in dir.listSync()) {
        if (file is File && file.path.endsWith('.desktop')) {
          final app = parseDesktopFile(file);
          if (app != null) apps.add(app);
        }
      }
    }
  }
  apps.sort((a, b) => a.name.compareTo(b.name));
  return apps;
}
