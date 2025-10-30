
import 'package:oxlauncher/utils/constants.dart';

class LauncherState {
  final List<LauncherScreen> screens;
  final List<ScreenItem> dockItems;

  LauncherState({required this.screens, required this.dockItems});

  Map<String, dynamic> toJson() => {
    'screens': screens.map((s) => s.toJson()).toList(),
    'dock': dockItems.map((item) => item.toJson()).toList(),
  };

  factory LauncherState.fromJson(Map<String, dynamic> json) {
    final screens = (json['screens'] as List?)?.map(
          (e) => LauncherScreen.fromJson(e as Map<String, dynamic>),
    ).toList() ?? [];

    final dockJson = json['dock'] as List?;
    final dockItems = <ScreenItem>[];

    if (dockJson != null) {
      for (int i = 0; i < dockJson.length && i < kNumDockIcons; i++) {
        final e = dockJson[i] as Map<String, dynamic>;
        dockItems.add(ScreenItem.fromJson(e));
      }
    }

    // Ensure exactly kNumDockIcons dock items
    while (dockItems.length < kNumDockIcons) {
      dockItems.add(ScreenItem.empty(0, dockItems.length));
    }

    return LauncherState(screens: screens, dockItems: dockItems);
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
  final Application? app;

  const ScreenItem({required this.row, required this.col, this.app});

  static ScreenItem empty(int row, int col) => ScreenItem(row: row, col: col);

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
