import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/progress.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/legal/legal_text.dart';

void main() {
  tearDown(() => L10n.lang.value = AppLang.de);

  test('German is the default and English follows the switch', () {
    expect(tr('Hallo', 'Hello'), 'Hallo');
    L10n.lang.value = AppLang.en;
    expect(tr('Hallo', 'Hello'), 'Hello');
  });

  test('names of data classes follow the language', () {
    expect(BotLevel.easy.label, 'LEICHT');
    expect(Rank.of(0).title, 'Rekrut');
    L10n.lang.value = AppLang.en;
    expect(BotLevel.easy.label, 'EASY');
    expect(Rank.of(0).title, 'Recruit');
  });

  test('every achievement is described in both languages', () {
    for (final lang in AppLang.values) {
      L10n.lang.value = lang;
      for (final achievement in Achievement.all) {
        expect(achievement.title, isNotEmpty);
        expect(achievement.description, isNotEmpty);
      }
    }
  });

  test('the English legal texts mirror the German ones', () {
    expect(imprintEn.length, imprint.length);
    expect(privacyEn.length, privacy.length);
  });
}
