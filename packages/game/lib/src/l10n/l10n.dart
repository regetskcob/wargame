import 'dart:ui' show PlatformDispatcher, Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The languages the game speaks.
enum AppLang {
  de('DE', 'Deutsch', Locale('de')),
  en('EN', 'English', Locale('en'));

  const AppLang(this.code, this.label, this.locale);

  final String code;
  final String label;
  final Locale locale;
}

const _langKey = 'panzergefecht.lang';

/// The language of every text on screen. German until [init] has looked at
/// the device, which keeps the tests and the first frame deterministic.
class L10n {
  static final lang = ValueNotifier<AppLang>(AppLang.de);

  static AppLang get current => lang.value;

  /// Picks the saved language, else the one of the device: German for
  /// German devices, English for everything else.
  static Future<void> init() async {
    AppLang? saved;
    try {
      final code = await SharedPreferencesAsync().getString(_langKey);
      saved = AppLang.values.where((l) => l.code == code).firstOrNull;
    } on Object {
      // Without a store the device language decides on every start.
    }
    lang.value =
        saved ??
        (PlatformDispatcher.instance.locale.languageCode == 'de'
            ? AppLang.de
            : AppLang.en);
  }

  static Future<void> set(AppLang value) async {
    lang.value = value;
    try {
      await SharedPreferencesAsync().setString(_langKey, value.code);
    } on Object {
      // The choice then only lasts until the game is closed.
    }
  }
}

/// The text in the current language: [de] in German, [en] otherwise.
String tr(String de, String en) => L10n.current == AppLang.de ? de : en;
