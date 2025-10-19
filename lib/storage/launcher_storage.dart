import 'dart:convert';
import 'dart:io';
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
    if (!file.existsSync()) {
      final defaultState = _createDefaultState(defaultDockApps);
      await saveState(defaultState);
      return defaultState;
    }
    print(path);
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
    Application(name: 'Phone', iconPath: 'phone.png'),
    Application(name: 'WhatsApp', iconPath: 'whatsapp.png'),
    Application(name: 'Camera', iconPath: 'camerapro.png'),
    Application(name: 'Mail', iconPath: 'com_google_android_gm.png'),
    Application(name: 'Browser', iconPath: 'firefox_nightly.png'),
  ];

  static LauncherScreen _createDefaultScreen() {
    final items = <ScreenItem>[];
    for (int i = 0; i < 25; i++) {
      items.add(ScreenItem(
        app: Application(name: _toAppName(someApps[i]), iconPath: someApps[i]),
        row: i ~/ 5,
        col: i % 5,
      ));
    }
    return LauncherScreen(items: items);
  }
}

String _toAppName(String imagePath) {
  if (imagePath.endsWith(".png")) {
    return imagePath.substring(0, imagePath.length-4);
  }
  return imagePath;
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

Application getAppAt({
  required List<ScreenItem> items,
  required int row,
  required int col,
}) {
  try {
    return items.firstWhere((item) => item.row == row && item.col == col).app;
  } catch (_) {
    // Return invisible placeholder
    return Application(name: '', iconPath: 'placeholder.png');
  }
}

final someApps = [
  "abc.png", "abdelrahman_wifianalyzerpro.png", "ac3_video_player.png", "accuweather.png",
  "linkedin.png", "my_o2.png", "newpipe.png", "google_maps.png", "google_messages.png", "google_youtube.png",
  "oneplus_mobile.png", "shazam.png", "signal.png", "slack.png", "spotify.png", "telegram.png",
  "ai_perplexity_app_android.png", "airbnb.png", "aj_english.png", "amazon_kindle.png", "amazon_shopping.png", "american_airlines.png",
  "amex_uk.png", "aplicacion_tiempo.png", "app_1weather.png", "app_alextran_immich.png", "audible.png", "bbc_iplayer.png", "bbc_news.png",
  "bbva_spain.png", "calc_plus.png", "camerapro.png", "ch_protonvpn_android.png", "com_google_android_apps_docs.png",
  "com_google_android_apps_walletnfcrel.png", "com_google_android_gm.png", "com_google_ar_lens.png", "phone.png",
  "com_openai_chatgpt.png", "firefox_nightly.png", "google_calendar.png", "google_chrome.png", "google_earth.png", "google_keep.png",
  "google_play_services.png", "google_search.png", "google_wallet.png",
  "whatsapp.png", "oneplus_camera.png", "oneplus_community.png", "oneplus_consumer_android.png",
];

