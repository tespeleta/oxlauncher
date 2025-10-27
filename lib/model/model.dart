import 'package:oxlauncher/storage/launcher_storage.dart';

class LauncherState {
  final List<LauncherScreen> screens;
  final List<Application> dockApps;

  LauncherState({required this.screens, required this.dockApps});

  Map<String, dynamic> toJson() => {
    'screens': screens.map((s) => s.toJson()).toList(),
    'dock': dockApps.map((a) => {'name': a.name, 'iconPath': a.iconPath}).toList(),
  };

  factory LauncherState.fromJson(Map<String, dynamic> json) {
    final screens = (json['screens'] as List?)?.map(
            (e) => LauncherScreen.fromJson(e as Map<String, dynamic>)
    ).toList() ?? [];
    final dockJson = json['dock'] as List?;
    final dockApps = dockJson?.map((e) => Application(
          name: e['name'] as String,
          iconPath: e['iconPath'] as String,
          exec: e['exec'] as String,
          desktopFilePath: e['desktopFilePath'] as String)
    ).toList() ?? LauncherStorage.defaultDockApps;

    return LauncherState(screens: screens, dockApps: dockApps);
  }
}

class LauncherScreen {
  final List<ScreenItem> items;
  LauncherScreen({required this.items});

  Map<String, dynamic> toJson() => {'items': items.map((i) => i.toJson()).toList()};
  factory LauncherScreen.fromJson(Map<String, dynamic> json) =>
      LauncherScreen(items: (json['items'] as List).map((e) => ScreenItem.fromJson(e)).toList());
}

class Application {
  final String name;
  final String exec;      // the executable command
  final String iconPath;  // icon filename or full path
  final String desktopFilePath; // full path to .desktop file

  const Application({
    required this.name,
    required this.exec,
    required this.iconPath,
    required this.desktopFilePath,
  });

  @override
  String toString() => '$name -> $exec (icon: $iconPath)';
}

class ScreenItem {
  final int row;
  final int col;
  Application? app;

  ScreenItem({required this.row, required this.col, this.app});

  Map<String, dynamic> toJson() => {
    'name': app?.name ?? '',
    'iconPath': app?.iconPath ?? '',
    'exec': app?.exec ?? '',
    'desktopFilePath': app?.desktopFilePath ?? '',
    'row': row,
    'col': col,
  };

  factory ScreenItem.fromJson(Map<String, dynamic> json) => ScreenItem(
    app: json['name'] != '' ? Application(
      name: json['name'],
      iconPath: json['iconPath'],
      exec: json['exec'] ?? '',
      desktopFilePath: json['desktopFilePath'],
    ): null,
    row: json['row'],
    col: json['col'],
  );
}
