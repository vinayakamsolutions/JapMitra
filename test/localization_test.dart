import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:japmitra/core/localization/app_localizations.dart';

void main() {
  test('language switching maps app name', () async {
    final hi = await AppLocalizations.delegate.load(const Locale('hi'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(hi.t('tag'), contains('आध्यात्मिक'));
    expect(en.t('tag'), contains('Spiritual'));
  });
}
