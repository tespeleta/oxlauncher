
class LauncherState {
  final List<LauncherScreen> screens;
  final List<DockItem> dockItems;

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
    final dockItems = <DockItem>[];

    if (dockJson != null) {
      for (int i = 0; i < dockJson.length && i < 5; i++) {
        final e = dockJson[i] as Map<String, dynamic>;
        dockItems.add(DockItem.fromJson(e, i));
      }
    }

    // Ensure exactly 5 dock items
    while (dockItems.length < 5) {
      dockItems.add(DockItem.empty(dockItems.length));
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

class DockItem {
  final Application? app;
  final int index;

  const DockItem({this.app, required this.index});

  static DockItem empty(int index) => DockItem(index: index);

  Map<String, dynamic> toJson() {
    final a = app;
    return {
      'name': a?.name ?? '',
      'iconPath': a?.iconPath ?? '',
      'exec': a?.exec ?? '',
      'desktopFilePath': a?.desktopFilePath ?? '',
    };
  }

  static DockItem fromJson(Map<String, dynamic> json, int index) {
    if (json['name'] == '') {
      return DockItem(index: index);
    }
    return DockItem(
      app: Application(
        name: json['name'] as String,
        iconPath: json['iconPath'] as String,
        exec: json['exec'] as String? ?? '',
        desktopFilePath: json['desktopFilePath'] as String? ?? '',
      ),
      index: index,
    );
  }
}

// Convert DockItem list → ScreenItem list (1 row, 5 cols)
List<ScreenItem> dockToGridItems(List<DockItem> dock) {
  return List.generate(5, (col) {
    return ScreenItem(
      row: 0,
      col: col,
      app: dock[col].app,
    );
  });
}

// Convert ScreenItem list (1×5) → DockItem list
List<DockItem> gridToDockItems(List<ScreenItem> items) {
  return List.generate(5, (i) {
    final item = items.firstWhere((it) => it.col == i, orElse: () => ScreenItem(row: 0, col: i));
    return DockItem(app: item.app, index: i);
  });
}