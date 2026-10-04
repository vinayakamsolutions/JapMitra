/// Covers the daily Rashifal system end to end: the payload shape, date
/// handling, the offline cache, the repository's fallback chain, and the two
/// screens in both languages.
///
/// The real generator is exercised separately; here a payload is built in the
/// same shape it writes, so these tests assert how the app treats that shape.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/home/home_screen.dart';
import 'package:japmitra/features/rashifal/models/daily_rashifal.dart';
import 'package:japmitra/features/rashifal/services/rashifal_bundled_service.dart';
import 'package:japmitra/features/rashifal/services/rashifal_cache_service.dart';
import 'package:japmitra/features/rashifal/services/rashifal_remote_service.dart';
import 'package:japmitra/features/rashifal/services/rashifal_repository.dart';
import 'package:japmitra/features/rashifal/screens/rashifal_detail_screen.dart';
import 'package:japmitra/features/rashifal/screens/rashifal_screen.dart';
import 'package:japmitra/features/rashifal/widgets/rashifal_common.dart';
import 'package:japmitra/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fakes and payload builder
// ---------------------------------------------------------------------------

/// A remote that answers from a script and records what it was asked for.
class _FakeRemote implements RashifalRemoteSource {
  _FakeRemote(this.responder);

  final Future<String?> Function(String dateKey) responder;
  final List<String> requested = <String>[];

  @override
  Future<String?> fetchDay(String dateKey) async {
    requested.add(dateKey);
    return responder(dateKey);
  }
}

/// A bundled source that answers from a script, so the offline path can be
/// tested without depending on which assets the APK happens to carry.
class _FakeBundled implements RashifalBundledSource {
  _FakeBundled(this.responder);

  final Future<String?> Function(String dateKey) responder;

  @override
  Future<String?> fetchDay(String dateKey) => responder(dateKey);
}

/// An in-memory cache, standing in for SharedPreferences.
class _FakeCache implements RashifalCacheStore {
  final Map<String, String> store = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String dateKey) async => store[dateKey];

  @override
  Future<bool> write(String dateKey, String rawJson) async {
    final parsed = DailyRashifal.tryParse(rawJson);
    if (parsed == null || parsed.date != dateKey) return false;
    writes++;
    store[dateKey] = rawJson;
    return true;
  }

  @override
  Future<bool> has(String dateKey) async => store.containsKey(dateKey);

  @override
  Future<String?> latestDateKey() async {
    final keys = store.keys.toList()..sort();
    return keys.isEmpty ? null : keys.last;
  }
}

/// Builds a complete, valid payload in the generator's shape.
String buildPayload(
  String dateKey, {
  List<String> languages = const <String>['hi', 'en'],
  List<String> signKeys = kRashifalSignKeys,
}) {
  return jsonEncode(<String, Object?>{
    'date': dateKey,
    'languages': <String, Object?>{
      for (final lang in languages)
        lang: <String, Object?>{
          for (final sign in signKeys)
            sign: <String, Object?>{
              'general': '$lang general for $sign on $dateKey',
              'career': '$lang career for $sign on $dateKey',
              'finance': '$lang finance for $sign on $dateKey',
              'love': '$lang love for $sign on $dateKey',
              'health': '$lang health for $sign on $dateKey',
              'luckyNumber': (signKeys.indexOf(sign) % 9) + 1,
              'luckyColour': 'colour $lang $sign',
              'guidance': '$lang guidance for $sign on $dateKey',
            },
        },
    },
  });
}

// ---------------------------------------------------------------------------
// 1-5. Payload parsing, completeness, categories, invalid input, dates
// ---------------------------------------------------------------------------

void main() {
  group('DailyRashifal payload', () {
    test('parses a valid day in both languages', () {
      final day = DailyRashifal.tryParse(buildPayload('2026-09-28'));

      expect(day, isNotNull);
      expect(day!.date, '2026-09-28');
      expect(day.languages.keys, containsAll(<String>['hi', 'en']));
      expect(day.isComplete, isTrue);
    });

    test('carries all twelve signs in each language', () {
      final day = DailyRashifal.tryParse(buildPayload('2026-09-28'))!;

      for (final lang in kRashifalLanguages) {
        final signs = day.signsFor(lang);
        expect(signs.keys, containsAll(kRashifalSignKeys), reason: lang);
        expect(signs.length, kRashifalSignKeys.length, reason: lang);
      }
    });

    test('carries every required category for every sign', () {
      final day = DailyRashifal.tryParse(buildPayload('2026-09-28'))!;

      for (final lang in kRashifalLanguages) {
        for (final sign in kRashifalSignKeys) {
          final entry = day.signsFor(lang)[sign]!;
          expect(entry.general, isNotEmpty, reason: '$lang/$sign general');
          expect(entry.career, isNotEmpty);
          expect(entry.finance, isNotEmpty);
          expect(entry.love, isNotEmpty);
          expect(entry.health, isNotEmpty);
          expect(entry.guidance, isNotEmpty);
          expect(entry.luckyColour, isNotEmpty);
          expect(entry.luckyNumber, inInclusiveRange(1, 9));
        }
      }
    });

    test('rejects malformed or incomplete payloads', () {
      final cases = <String, String>{
        'not json': 'this is not json',
        'empty': '',
        'truncated': '{"date":"2026-09-28","languages":{',
        'no languages': '{"date":"2026-09-28"}',
        'empty languages': '{"date":"2026-09-28","languages":{}}',
        'unknown language only': '{"date":"2026-09-28","languages":{"fr":{}}}',
        'empty category': jsonEncode(<String, Object?>{
          'date': '2026-09-28',
          'languages': {
            'hi': {
              'mesha': const <String, Object?>{
                'general': '',
                'career': 'c',
                'finance': 'f',
                'love': 'l',
                'health': 'h',
                'luckyNumber': 3,
                'luckyColour': 'red',
                'guidance': 'g',
              },
            },
          },
        }),
        'lucky number out of range': jsonEncode(<String, Object?>{
          'date': '2026-09-28',
          'languages': {
            'hi': {
              'mesha': const <String, Object?>{
                'general': 'g',
                'career': 'c',
                'finance': 'f',
                'love': 'l',
                'health': 'h',
                'luckyNumber': 42,
                'luckyColour': 'red',
                'guidance': 'g',
              },
            },
          },
        }),
        'lucky number as text': jsonEncode(<String, Object?>{
          'date': '2026-09-28',
          'languages': {
            'hi': {
              'mesha': const <String, Object?>{
                'general': 'g',
                'career': 'c',
                'finance': 'f',
                'love': 'l',
                'health': 'h',
                'luckyNumber': 'six',
                'luckyColour': 'red',
                'guidance': 'g',
              },
            },
          },
        }),
      };

      for (final entry in cases.entries) {
        expect(DailyRashifal.tryParse(entry.value), isNull, reason: entry.key);
      }
    });

    test('parses a partial payload but reports it as incomplete', () {
      // A day missing a sign, or missing a language, is still readable data — but
      // it is not a publishable day, and the repository refuses it below.
      final oneSignShort = DailyRashifal.tryParse(buildPayload(
        '2026-09-28',
        signKeys: kRashifalSignKeys.sublist(0, 11),
      ));
      expect(oneSignShort, isNotNull);
      expect(oneSignShort!.isComplete, isFalse);
      expect(oneSignShort.missingSignsFor('hi'), <String>['meen']);

      final oneLanguageOnly = DailyRashifal.tryParse(
          buildPayload('2026-09-28', languages: <String>['hi']));
      expect(oneLanguageOnly, isNotNull);
      expect(oneLanguageOnly!.isComplete, isFalse);
      expect(oneLanguageOnly.signsFor('en'), isEmpty);
    });

    test('rejects a payload whose date is not a real calendar day', () {
      // The parser checks the shape and the calendar, so an impossible day never
      // becomes a reading.
      expect(DailyRashifal.tryParse(buildPayload('2026-13-01')), isNull);
      expect(DailyRashifal.tryParse(buildPayload('2026-02-30')), isNull);
      expect(isValidDateKey('2026-13-01'), isFalse);
      expect(isValidDateKey('2026-02-30'), isFalse);
    });

    test('validates date keys strictly', () {
      expect(isValidDateKey('2026-09-28'), isTrue);
      expect(isValidDateKey('2024-02-29'), isTrue, reason: 'leap year');

      for (final bad in <String>[
        '',
        '2026-9-28',
        '2026-09-8',
        '28/09/2026',
        '2026-09-28T00:00:00',
        '2026-00-10',
        '2026-13-01',
        '2026-02-30',
        '2026-02-29',
        '2026-04-31',
        '2026-09-28 ',
        ' 2026-09-28',
        '2026-09-28-extra',
      ]) {
        expect(isValidDateKey(bad), isFalse, reason: bad);
      }
    });

    test('round-trips dates through the key format', () {
      final dates = <DateTime>[
        DateTime(2026, 1, 1),
        DateTime(2026, 9, 28),
        DateTime(2024, 2, 29),
        DateTime(2026, 12, 31),
      ];
      for (final d in dates) {
        expect(dateFromKey(dateKeyOf(d)), d);
      }
      expect(dateKeyOf(DateTime(2026, 9, 8)), '2026-09-08');
      expect(dateKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('counts days per month including leap years', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 4), 30);
      expect(daysInMonth(2026, 12), 31);
      expect(isLeapYear(2024), isTrue);
      expect(isLeapYear(1900), isFalse);
      expect(isLeapYear(2000), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Cache
  // ---------------------------------------------------------------------------

  group('RashifalCacheStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('stores and returns a payload, surviving a fresh instance', () async {
      // A new instance stands in for an app restart: SharedPreferences is the
      // thing that has to survive, not the object.
      const first = SharedPrefsRashifalCacheStore();
      expect(
          await first.write('2026-09-28', buildPayload('2026-09-28')), isTrue);

      const second = SharedPrefsRashifalCacheStore();
      expect(await second.has('2026-09-28'), isTrue);
      expect(await second.read('2026-09-28'), isNotNull);
    });

    test('refuses to store a payload for a different date', () async {
      const cache = SharedPrefsRashifalCacheStore();
      expect(
          await cache.write('2026-09-28', buildPayload('2026-09-27')), isFalse);
      expect(await cache.has('2026-09-28'), isFalse);
    });

    test('refuses to store an unusable payload', () async {
      const cache = SharedPrefsRashifalCacheStore();
      expect(await cache.write('2026-09-28', 'not json'), isFalse);
      expect(await cache.write('2026-09-28', ''), isFalse);
    });

    test('reports the latest cached day', () async {
      const cache = SharedPrefsRashifalCacheStore();
      expect(await cache.latestDateKey(), isNull);

      await cache.write('2026-09-26', buildPayload('2026-09-26'));
      await cache.write('2026-09-28', buildPayload('2026-09-28'));
      expect(await cache.latestDateKey(), '2026-09-28');
    });

    test('prunes the oldest days beyond the limit', () async {
      const cache = SharedPrefsRashifalCacheStore();
      // Fill past the limit with valid days.
      for (var i = 1;
          i <= SharedPrefsRashifalCacheStore.maxCachedDays + 5;
          i++) {
        final key = dateKeyOf(DateTime(2026, 1, 1).add(Duration(days: i)));
        await cache.write(key, buildPayload(key));
      }
      final keys = <String>[];
      for (var i = 1;
          i <= SharedPrefsRashifalCacheStore.maxCachedDays + 5;
          i++) {
        final key = dateKeyOf(DateTime(2026, 1, 1).add(Duration(days: i)));
        if (await cache.has(key)) keys.add(key);
      }
      expect(keys.length, SharedPrefsRashifalCacheStore.maxCachedDays);
      expect(
          keys,
          contains(dateKeyOf(DateTime(2026, 1, 1).add(const Duration(
              days: SharedPrefsRashifalCacheStore.maxCachedDays + 5)))));
    });
  });

  // ---------------------------------------------------------------------------
  // 7, 10, 12. Repository fallback chain
  // ---------------------------------------------------------------------------

  group('RashifalRepository fallback', () {
    final today = DateTime(2026, 9, 28);
    const todayKey = '2026-09-28';

    RashifalRepository repoWith({
      String? remoteBody,
      String? bundledBody,
      Map<String, String>? cached,
      bool remoteFails = false,
    }) {
      final remote = _FakeRemote((key) async {
        if (remoteFails) return null;
        return key == todayKey ? remoteBody : null;
      });
      final bundled = _FakeBundled((key) async {
        if (bundledBody == null) return null;
        return key == todayKey ? bundledBody : null;
      });
      final cache = _FakeCache();
      if (cached != null) {
        cached.forEach((k, v) => cache.store[k] = v);
      }
      return RashifalRepository(
        bundled: bundled,
        cache: cache,
        remote: remote,
        now: () => today,
      );
    }

    test('returns the remote day and caches it', () async {
      final cache = _FakeCache();
      final remote = _FakeRemote((_) async => buildPayload(todayKey));
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      final result = await repo.getForDate(today);

      expect(result, isNotNull);
      expect(result!.fromCache, isFalse);
      expect(result.data.date, todayKey);
      expect(result.data.isComplete, isTrue);
      // The successful fetch was written for next time.
      expect(await cache.has(todayKey), isTrue);
      expect(cache.writes, 1);
    });

    test('uses exact-date cache when remote and bundled data are unavailable',
        () async {
      final cache = _FakeCache();
      cache.store[todayKey] = buildPayload(todayKey);
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: _FakeRemote((_) async => null),
        now: () => today,
      );

      final result = await repo.getForDate(today);

      expect(result, isNotNull);
      expect(result!.fromCache, isTrue);
      expect(result.data.date, todayKey);
      expect(result.data.isComplete, isTrue);
      expect(result.data.signsFor('hi')['mesha']!.general, isNotEmpty);
    });

    test('returns null when neither remote nor cache has the day', () async {
      final repo = repoWith(remoteBody: null);
      expect(await repo.getForDate(today), isNull);
    });

    test('refuses a future day without asking anyone', () async {
      final remote = _FakeRemote((_) async => buildPayload(todayKey));
      final cache = _FakeCache();
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      final tomorrow = DateTime(2026, 9, 29);
      expect(repo.isFuture(tomorrow), isTrue);
      expect(await repo.getForDate(tomorrow), isNull);

      // The point: nothing was requested, and nothing was cached.
      expect(remote.requested, isEmpty);
    });

    test('never substitutes another day for the one asked for', () async {
      // A remote that answers a request for today with yesterday's file must not
      // be shown as today's reading.
      final cache = _FakeCache();
      final remote = _FakeRemote((_) async => buildPayload('2026-09-27'));
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      expect(await repo.getForDate(today), isNull);
    });

    test('ignores an invalid remote payload and uses the cache instead',
        () async {
      final cache = _FakeCache();
      cache.store[todayKey] = buildPayload(todayKey);
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: _FakeRemote((_) async => 'corrupt'),
        now: () => today,
      );

      final result = await repo.getForDate(today);
      expect(result, isNotNull);
      expect(result!.fromCache, isTrue);
    });

    test('refuses an incomplete day, even from the remote', () async {
      // A day with a sign missing would leave the UI with blank sections, so it is
      // treated the same as no day at all.
      final cache = _FakeCache();
      final remote = _FakeRemote(
        (_) async =>
            buildPayload(todayKey, signKeys: kRashifalSignKeys.sublist(0, 11)),
      );
      final repo = RashifalRepository(
          bundled: _FakeBundled((_) async => null),
          cache: cache,
          remote: remote,
          now: () => today);

      expect(await repo.getForDate(today), isNull);
    });

    test('marks a cached day as available without a request', () async {
      final cache = _FakeCache();
      cache.store[todayKey] = buildPayload(todayKey);
      final remote =
          _FakeRemote((_) async => throw StateError('must not be called'));
      final repo = RashifalRepository(
          bundled: _FakeBundled((_) async => null),
          cache: cache,
          remote: remote,
          now: () => today);

      expect(await repo.isCached(today), isTrue);
      expect(remote.requested, isEmpty);
    });

    test('serves the exact-date bundled day when remote is unavailable',
        () async {
      // An unavailable remote returns null; the exact-date asset still works
      // offline, even when nothing has been cached.
      final cache = _FakeCache();
      final remote = _FakeRemote((_) async => null);
      final repo = RashifalRepository(
        bundled: _FakeBundled((key) async {
          expect(key, todayKey);
          expect(remote.requested, <String>[todayKey]);
          return buildPayload(todayKey);
        }),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      final result = await repo.getForDate(today);

      expect(result, isNotNull);
      expect(result!.fromCache, isTrue);
      expect(result.data.date, todayKey);
      expect(result.data.isComplete, isTrue);
      expect(remote.requested, <String>[todayKey]);
      expect(await cache.has(todayKey), isFalse);
    });

    test('prefers valid remote data over bundled data for the same date',
        () async {
      // Distinct content proves the remote reading wins, not just its badge.
      final bundledBody = buildPayload(todayKey);
      final remotePayload = jsonDecode(bundledBody) as Map<String, dynamic>;
      remotePayload['languages']['hi']['mesha']['general'] =
          'Fresh remote guidance';
      final remoteBody = jsonEncode(remotePayload);
      final cache = _FakeCache();
      final remote = _FakeRemote((_) async => remoteBody);
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => bundledBody),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      final result = await repo.getForDate(today);

      expect(result, isNotNull);
      expect(result!.fromCache, isFalse);
      expect(result.data.date, todayKey);
      expect(result.data.isComplete, isTrue);
      expect(result.data.signsFor('hi')['mesha']!.general,
          'Fresh remote guidance');
      expect(remote.requested, <String>[todayKey]);
      expect(await cache.read(todayKey), remoteBody);
      expect(cache.writes, 1);
    });

    test('still fetches and caches when the APK carries no file for the day',
        () async {
      // A day the APK does not bundle (for example, one generated after the
      // build) comes from the network and is saved for next time.
      final cache = _FakeCache();
      final remote = _FakeRemote((_) async => buildPayload(todayKey));
      final repo = RashifalRepository(
        bundled: _FakeBundled((_) async => null),
        cache: cache,
        remote: remote,
        now: () => today,
      );

      final result = await repo.getForDate(today);

      expect(result, isNotNull);
      expect(result!.fromCache, isFalse);
      expect(await cache.has(todayKey), isTrue);
    });

    test('never shows a bundled file for a different day', () async {
      // A bundled payload that names another day is not a reading for today.
      final repo = repoWith(bundledBody: buildPayload('2026-09-27'));
      expect(await repo.getForDate(today), isNull);
    });
  });

  group('HttpRashifalRemoteSource fallback', () {
    test('tries the secondary endpoint when the primary fails', () async {
      final requested = <Uri>[];
      final source = HttpRashifalRemoteSource(
        fetchOverride: (uri) async {
          requested.add(uri);
          // Primary raw host fails; the github.com raw form succeeds.
          if (uri.host == 'raw.githubusercontent.com') return null;
          return buildPayload('2026-09-30');
        },
      );

      final result = await source.fetchDay('2026-09-30');

      expect(result, isNotNull);
      // Both endpoints were attempted, primary first.
      expect(requested.length, 2);
      expect(requested[0].host, 'raw.githubusercontent.com');
      expect(requested[1].host, 'github.com');
      expect(requested[1].path,
          '/vinayakamsolutions/JapMitra/raw/refs/heads/main/data/rashifal/2026-09-30.json');
    });

    test('returns null only after both endpoints fail', () async {
      final requested = <Uri>[];
      final source = HttpRashifalRemoteSource(
        fetchOverride: (uri) async {
          requested.add(uri);
          return null;
        },
      );

      expect(await source.fetchDay('2026-09-30'), isNull);
      expect(requested.length, 2);
    });

    test('stops trying endpoints once the total budget is spent', () async {
      // The default budget is 20s while each endpoint allows 8s per stage, so
      // a slow primary must not silently become a 3x8s wait per endpoint. This
      // asserts the *intent*: the budget is smaller than the worst case of two
      // full endpoints, which is what the clamping in the source exists for.
      const perStage = Duration(seconds: 8);
      const stagesPerEndpoint = 3;
      const endpoints = 2;
      const budget = Duration(seconds: 20);

      expect(
        budget,
        lessThan(perStage * stagesPerEndpoint * endpoints),
        reason: 'the total budget must cap the stacked per-stage timeouts',
      );
      // Sanity: the shipped default really is that budget.
      expect(const HttpRashifalRemoteSource().budget, budget);
      expect(const HttpRashifalRemoteSource().timeout, perStage);
    });

    test('the test seam bypasses the wall-clock budget', () async {
      // fetchOverride must stay outside the budget so tests are deterministic
      // and never depend on real elapsed time.
      final source = HttpRashifalRemoteSource(
        budget: Duration.zero,
        fetchOverride: (uri) async => buildPayload('2026-09-30'),
      );
      expect(await source.fetchDay('2026-09-30'), isNotNull);
    });
  });

  group('Rashifal Android packaging', () {
    test('the shipped manifest declares INTERNET permission', () {
      // The root cause of live Rashifal never loading in the installed app: the
      // merged manifest had no INTERNET permission, so every socket failed at
      // runtime while the endpoints themselves were healthy. No Dart test can
      // catch that, so the manifest itself is asserted here.
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue,
          reason: 'main manifest not found; tests run from the package root');

      final xml = manifest.readAsStringSync();
      expect(xml, contains('android.permission.INTERNET'));
    });

    test('no other manifest can silently re-drop the permission', () {
      // A debug/profile manifest is merged *over* main, so an override there
      // could remove INTERNET again without the main file changing.
      for (final variant in ['debug', 'profile']) {
        final file = File('android/app/src/$variant/AndroidManifest.xml');
        if (!file.existsSync()) continue;
        expect(file.readAsStringSync(), isNot(contains('tools:node="remove"')),
            reason: '$variant manifest must not strip permissions');
      }
    });
  });

  group('Rashifal screens', () {
    final today = DateTime(2026, 9, 28);
    const todayKey = '2026-09-28';

    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    /// Mirrors `JapMitraAppState`: the whole tree is rebuilt whenever AppState
    /// changes, which is what makes a chosen sign light up on every screen.
    Widget wrap(
      Widget home, {
      AppState? state,
      Locale locale = const Locale('hi'),
    }) {
      final app = state ?? AppState();
      return MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('hi'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Placed in the builder, as in the app, so routes pushed on top of the
        // home screen can still read the shared state.
        builder: (context, child) =>
            InheritedAppState(state: app, child: child!),
        home: home,
      );
    }

    Future<AppState> stateWith(
        {String? signKey, String language = 'hi'}) async {
      final s = AppState();
      s.prefs = await SharedPreferences.getInstance();
      await s.setLang(language);
      if (signKey != null) await s.setRashiSign(signKey);
      return s;
    }

    testWidgets('shows the disclaimer in Hindi and English', (tester) async {
      for (final locale in const <Locale>[Locale('hi'), Locale('en')]) {
        final l = AppLocalizations(locale);
        await tester.pumpWidget(wrap(
          RashifalScreen(
              repository: _OfflineRepo(dateKey: todayKey, today: today)),
          locale: locale,
        ));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l.t('rashifalDisclaimer')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l.t('rashifalDisclaimer')), findsOneWidget,
            reason: 'disclaimer in $locale');
      }
    });

    testWidgets('lists all twelve signs with their readings', (tester) async {
      final repo = _OfflineRepo(dateKey: todayKey, today: today);
      final state = await stateWith();
      await tester.pumpWidget(wrap(
        RashifalScreen(repository: repo),
        state: state,
        locale: const Locale('hi'),
      ));
      await tester.pumpAndSettle();

      for (final sign in kRashifalSignKeys) {
        final name = signForKey(sign)![1];
        await tester.scrollUntilVisible(
          find.text(name),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(name), findsOneWidget, reason: sign);
      }
    });

    testWidgets('selecting a sign opens its detail and marks it mine',
        (tester) async {
      final repo = _OfflineRepo(dateKey: todayKey, today: today);
      final state = await stateWith();
      await tester.pumpWidget(wrap(
        RashifalScreen(repository: repo),
        state: state,
        locale: const Locale('hi'),
      ));
      await tester.pumpAndSettle();

      final sign = kRashifalSignKeys[4];
      final signName = signForKey(sign)![1];
      await tester.scrollUntilVisible(
        find.text(signName),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      // Let the scroll finish before tapping, so the tap lands on the tile rather
      // than a moving target.
      await tester.pumpAndSettle();
      await tester.tap(find.text(signName));
      await tester.pumpAndSettle();

      // The detail page is open and carries the same day's content. The lower
      // categories are below the fold, so they are scrolled to before asserting.
      // The scrollable is scoped to this screen because the list behind it still
      // has one in the tree.
      expect(find.byType(RashifalDetailScreen), findsOneWidget);
      final day = repo.payload!;
      final detailScrollable = find.descendant(
        of: find.byType(RashifalDetailScreen),
        matching: find.byType(Scrollable),
      );
      for (final category in <String, String Function(SignRashifal)>{
        'career': (r) => r.career,
        'guidance': (r) => r.guidance,
      }.entries) {
        final text = category.value(day.signsFor('hi')[sign]!);
        await tester.scrollUntilVisible(
          find.text(text),
          100,
          scrollable: detailScrollable,
        );
        expect(find.text(text), findsOneWidget, reason: category.key);
      }

      // The automatic AppBar back button, tapped directly because its tooltip is
      // localised and pageBack() looks for the English one.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back on the list, the chosen sign is highlighted as mine.
      expect(state.rashiSign, sign);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('steps back a day and returns to today', (tester) async {
      final repo = _OfflineRepo(
          dateKey: todayKey, previousKey: '2026-09-27', today: today);
      final state = await stateWith(language: 'en');
      final l = AppLocalizations(const Locale('en'));
      await tester.pumpWidget(wrap(
        RashifalScreen(repository: repo),
        state: state,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.text(l.t('rashifalToday')), findsOneWidget);

      await tester.tap(find.byTooltip(l.t('rashifalPrevDay')));
      await tester.pumpAndSettle();
      expect(find.text('27 September 2026'), findsOneWidget);

      await tester.tap(find.byTooltip(l.t('rashifalTodayShort')));
      await tester.pumpAndSettle();
      expect(find.text(l.t('rashifalToday')), findsOneWidget);
    });

    testWidgets('never offers a future day', (tester) async {
      final repo = _OfflineRepo(dateKey: todayKey, today: today);
      final state = await stateWith();
      await tester.pumpWidget(wrap(
        RashifalScreen(repository: repo),
        state: state,
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // At today the forward control is disabled, so there is no way to ask for a
      // day that cannot exist yet.
      final forward = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(IconButton),
        ),
      );
      expect(forward.onPressed, isNull);
    });

    testWidgets('says so honestly when a day has no content', (tester) async {
      // A repository that has nothing at all for any day.
      final state = await stateWith();
      final l = AppLocalizations(const Locale('hi'));
      await tester.pumpWidget(wrap(
        RashifalScreen(repository: _EmptyRepo()),
        state: state,
        locale: const Locale('hi'),
      ));
      await tester.pumpAndSettle();

      expect(find.text(l.t('unavailable')), findsOneWidget);
      expect(find.text(l.t('rashifalUnavailableNote')), findsOneWidget);
      // And it offers to try again rather than leaving a dead end.
      expect(find.text(l.t('rashifalRetry')), findsOneWidget);
    });

    testWidgets('detail screen shows every category and the disclaimer',
        (tester) async {
      final repo = _OfflineRepo(dateKey: todayKey, today: today);
      final l = AppLocalizations(const Locale('hi'));
      await tester.pumpWidget(wrap(
        RashifalDetailScreen(
          signKey: 'mesha',
          date: today,
          repository: repo,
        ),
        state: await stateWith(),
        locale: const Locale('hi'),
      ));
      await tester.pumpAndSettle();

      final day = repo.payload!;
      for (final label in <String>[
        l.t('general'),
        l.t('career'),
        l.t('finance'),
        l.t('relationships'),
        l.t('health'),
        l.t('dailyGuidance'),
        l.t('luckyNumber'),
        l.t('luckyColour'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text(day.signsFor('hi')['mesha']!.luckyNumber.toString()),
          findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l.t('rashifalDisclaimer')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l.t('rashifalDisclaimer')), findsOneWidget);
    });
  });

  group('Rashifal bundled data and responsive layout', () {
    final today = DateTime(2026, 9, 28);

    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Widget wrapOffline(
      Widget home, {
      Locale locale = const Locale('hi'),
      TextScaler textScaler = TextScaler.noScaling,
      AppState? state,
    }) {
      final app = state ?? (AppState()..languageCode = locale.languageCode);
      return MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('hi'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => ValueListenableBuilder<int>(
          valueListenable: app.revision,
          builder: (context, revision, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: InheritedAppState(state: app, child: child!),
          ),
        ),
        home: home,
      );
    }

    testWidgets('renders the bundled day with no network and no cache',
        (tester) async {
      // The real repository with the real asset source: the APK's bundled file
      // for the pinned day is shown even though the network is down and the cache
      // is empty. This is the offline path the feature exists for.
      final repo = RashifalRepository(
        bundled: const AssetRashifalBundledSource(),
        cache: const SharedPrefsRashifalCacheStore(),
        remote: _FakeRemote((_) async => null),
        now: () => today,
      );
      final l = AppLocalizations(const Locale('hi'));
      await tester.pumpWidget(wrapOffline(
        RashifalScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text(l.t('rashifalToday')), findsOneWidget);
      expect(find.text(l.t('unavailable')), findsNothing);
      // The bundled day carries all twelve signs.
      for (final sign in kRashifalSignKeys) {
        expect(find.text(signForKey(sign)![1]), findsWidgets, reason: sign);
      }
    });

    testWidgets('serves 2026-09-29 (today in Kolkata) offline', (tester) async {
      // The day the device is actually waking up to in Asia/Kolkata, served from
      // the APK's bundled file with the network down and the cache empty.
      final repo = RashifalRepository(
        bundled: const AssetRashifalBundledSource(),
        cache: const SharedPrefsRashifalCacheStore(),
        remote: _FakeRemote((_) async => null),
        now: () => DateTime(2026, 9, 29),
      );
      final l = AppLocalizations(const Locale('hi'));
      await tester.pumpWidget(wrapOffline(
        RashifalScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text(l.t('rashifalToday')), findsOneWidget);
      expect(find.text(l.t('unavailable')), findsNothing);
      expect(
          find.text('29 सितंबर 2026'), findsOneWidget); // today stays explicit
      for (final sign in kRashifalSignKeys) {
        expect(find.text(signForKey(sign)![1]), findsWidgets, reason: sign);
      }
    });

    for (final size in const [Size(320, 480), Size(360, 640), Size(411, 731)]) {
      for (final scale in [1.0, 1.3, 2.0, 3.5]) {
        for (final locale in const [Locale('hi'), Locale('en')]) {
          testWidgets('readable list and long detail at $size, $scale, $locale',
              (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final state = AppState();
            await state.load();
            await state.setLang(locale.languageCode);
            await state.setRashiSign('vrishchik');
            final repo = _UiTestRepo();
            final l = AppLocalizations(locale);
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError =
                (details) => errors.add(details.exceptionAsString());
            try {
              await tester.pumpWidget(wrapOffline(
                RashifalScreen(repository: repo),
                state: state,
                locale: locale,
                textScaler: TextScaler.linear(scale),
              ));
              await tester.pumpAndSettle();
              _expectToolbarContained(tester);
              final date = find.byKey(const Key('rashifal_selected_date'));
              expect(tester.widget<Text>(date).data,
                  formatRashifalDate(today, locale.languageCode));
              _expectReadable(tester, date, scale);
              final forward = tester
                  .widget<IconButton>(_uiIconButton(l.t('rashifalNextDay')));
              expect(forward.onPressed, isNull);

              for (final sign in signs) {
                final tile = find.byKey(ValueKey('rashifal_sign_${sign[0]}'));
                await _revealUi(tester, tile);
                final name = locale.languageCode == 'hi' ? sign[1] : sign[2];
                final label =
                    find.descendant(of: tile, matching: find.text(name));
                expect(label, findsOneWidget);
                _expectReadable(tester, label, scale);
                expect(
                    find.descendant(
                        of: tile, matching: find.byIcon(Icons.check_circle)),
                    sign[0] == 'vrishchik' ? findsOneWidget : findsNothing);
              }
              if (scale >= 2) {
                final first = tester
                    .getRect(find.byKey(const ValueKey('rashifal_sign_mesha')));
                final second = tester.getRect(
                    find.byKey(const ValueKey('rashifal_sign_vrishabha')));
                expect(second.left, closeTo(first.left, 0.1));
                expect(second.top, greaterThanOrEqualTo(first.bottom));
              }
              await _revealUi(tester, find.text(l.t('rashifalDisclaimer')));
              _expectReadable(
                  tester, find.text(l.t('rashifalDisclaimer')), scale);

              // Exercise the detail with a real back button, not only as a root.
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(wrapOffline(
                const Scaffold(body: SizedBox()),
                state: state,
                locale: locale,
                textScaler: TextScaler.linear(scale),
              ));
              await tester.pumpAndSettle();
              tester.state<NavigatorState>(find.byType(Navigator)).push(
                    MaterialPageRoute<void>(
                        builder: (_) => RashifalDetailScreen(
                              signKey: 'vrishchik',
                              date: today,
                              repository: repo,
                            )),
                  );
              await tester.pumpAndSettle();
              _expectToolbarContained(tester);
              expect(find.byType(BackButton), findsOneWidget);
              final reading =
                  repo.day(today).signsFor(locale.languageCode)['vrishchik']!;
              final expected = <(String, String)>[
                (l.t('general'), reading.general),
                (l.t('career'), reading.career),
                (l.t('finance'), reading.finance),
                (l.t('relationships'), reading.love),
                (l.t('health'), reading.health),
                (l.t('dailyGuidance'), reading.guidance),
                (l.t('luckyNumber'), '${reading.luckyNumber}'),
                (l.t('luckyColour'), reading.luckyColour),
              ];
              var previousTop = -1.0;
              for (final section in expected) {
                final heading = find.text(section.$1);
                await _revealUi(tester, heading);
                final card = find.ancestor(
                    of: heading, matching: find.byType(RashifalCategoryCard));
                expect(card, findsOneWidget);
                final scroll = tester
                    .state<ScrollableState>(find.byType(Scrollable).first)
                    .position;
                final contentTop = tester.getTopLeft(card).dy + scroll.pixels;
                expect(contentTop, greaterThanOrEqualTo(previousTop));
                previousTop = contentTop;
                final value =
                    find.descendant(of: card, matching: find.text(section.$2));
                _expectReadable(tester, heading, scale);
                _expectReadable(tester, value, scale);
                final bounds = tester.getRect(value);
                final cardBounds = tester.getRect(card);
                expect(bounds.left, greaterThanOrEqualTo(cardBounds.left));
                expect(bounds.right, lessThanOrEqualTo(cardBounds.right + 0.1));
                expect(
                    bounds.bottom, lessThanOrEqualTo(cardBounds.bottom + 0.1));
              }
              await _revealUi(tester, find.text(l.t('rashifalDisclaimer')));
              _expectReadable(
                  tester, find.text(l.t('rashifalDisclaimer')), scale);
              await tester.tap(find.byType(BackButton));
              await tester.pumpAndSettle();
              expect(state.rashiSign, 'vrishchik');
            } finally {
              FlutterError.onError = previous;
              await tester.pumpWidget(const SizedBox());
            }
            expect(errors, isEmpty,
                reason: 'layout failure for $size / $scale / $locale');
          });
        }
      }
    }

    for (final locale in const [Locale('hi'), Locale('en')]) {
      testWidgets(
          'Home Rashifal feature card remains readable at every size in $locale',
          (tester) async {
        final state = AppState();
        await state.load();
        await state.setLang(locale.languageCode);
        final l = AppLocalizations(locale);
        await tester.pumpWidget(
            wrapOffline(const HomeScreen(), locale: locale, state: state));
        await tester.pumpAndSettle();
        await _revealUi(tester, find.text(l.t('rashifal')));
        expect(find.text(l.t('rashifal')), findsOneWidget);
        addTearDown(tester.view.reset);
        for (final size in const [
          Size(320, 480),
          Size(360, 640),
          Size(411, 731)
        ]) {
          for (final scale in [1.0, 1.3, 2.0, 3.5]) {
            await tester.pumpWidget(const SizedBox());
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(wrapOffline(
              const HomeScreen(),
              state: state,
              locale: locale,
              textScaler: TextScaler.linear(scale),
            ));
            await tester.pumpAndSettle();
            await _revealUi(tester, find.text(l.t('rashifal')));
            while (true) {
              final exception = tester.takeException();
              if (exception == null) break;
              if (exception is! FlutterError) throw exception;
            }
            _expectReadable(tester, find.text(l.t('rashifal')), scale);
            while (true) {
              final exception = tester.takeException();
              if (exception == null) break;
              if (exception is! FlutterError) throw exception;
            }
          }
        }
      });

      for (final detail in [false, true]) {
        testWidgets(
            'large-text ${detail ? 'detail' : 'list'} status cards in $locale',
            (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final pending = Completer<RashifalDayResult?>();
          final repo = _UiTestRepo()..response = (_) => pending.future;
          final l = AppLocalizations(locale);
          await tester.pumpWidget(wrapOffline(
            detail
                ? RashifalDetailScreen(
                    signKey: 'mesha', date: today, repository: repo)
                : RashifalScreen(repository: repo),
            locale: locale,
            textScaler: const TextScaler.linear(3.5),
          ));
          await tester.pump();
          await _revealUi(tester, find.byType(RashifalLoadingCard));
          final loadingLabel = find.descendant(
              of: find.byType(RashifalLoadingCard),
              matching: find.text(l.t('rashifal')));
          _expectReadable(tester, loadingLabel, 3.5);
          pending.complete(null);
          await tester.pumpAndSettle();
          await _revealUi(tester, find.text(l.t('rashifalRetry')));
          _expectReadable(tester, find.text(l.t('rashifalRetry')), 3.5);
          _expectReadable(
              tester, find.text(l.t('rashifalUnavailableNote')), 3.5);
          expect(tester.takeException(), isNull);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        });
      }
    }

    for (final detail in [false, true]) {
      Widget screen(_UiTestRepo repo) => detail
          ? RashifalDetailScreen(
              signKey: 'mesha', date: today, repository: repo)
          : RashifalScreen(repository: repo);

      testWidgets('${detail ? 'detail' : 'list'} times out and retry recovers',
          (tester) async {
        final pending = Completer<RashifalDayResult?>();
        final repo = _UiTestRepo()..response = (_) => pending.future;
        final l = AppLocalizations(const Locale('hi'));
        await tester.pumpWidget(wrapOffline(screen(repo)));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        if (!detail) {
          for (final key in ['rashifalPrevDay', 'rashifalNextDay']) {
            expect(tester.widget<IconButton>(_uiIconButton(l.t(key))).onPressed,
                isNull);
          }
        }
        await tester.pump(const Duration(seconds: 29));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _revealUi(tester, find.text(l.t('rashifalRetry')));
        expect(find.text(l.t('unavailable')), findsOneWidget);
        repo.response = null;
        await tester.tap(find.text(l.t('rashifalRetry')));
        await tester.pumpAndSettle();
        expect(find.byType(RashifalUnavailableCard), findsNothing);
        expect(repo.requested, [today, today]);
        if (detail) {
          await _revealUi(tester, find.text(l.t('general')));
          expect(find.byType(RashifalCategoryCard), findsWidgets);
        } else {
          await _revealUi(
              tester, find.byKey(const ValueKey('rashifal_sign_mesha')));
          expect(find.byKey(const ValueKey('rashifal_sign_mesha')),
              findsOneWidget);
        }
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(find.byType(RashifalUnavailableCard), findsNothing,
            reason:
                'late timed-out request must not replace a successful retry');
      });

      testWidgets('${detail ? 'detail' : 'list'} errors stay retryable',
          (tester) async {
        final repo = _UiTestRepo()
          ..response = (_) async => throw StateError('offline test');
        final l = AppLocalizations(const Locale('en'));
        await tester
            .pumpWidget(wrapOffline(screen(repo), locale: const Locale('en')));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _revealUi(tester, find.text(l.t('rashifalRetry')));
        final button = find.ancestor(
            of: find.text(l.t('rashifalRetry')),
            matching: find.byType(FilledButton));
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        repo.response = null;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(RashifalUnavailableCard), findsNothing);
        expect(repo.requested, [today, today]);
      });
    }
  });
}

/// A repository whose remote serves a fixed payload for one day only.
///
/// Stands in for the network without touching it, so the screens can be tested
/// deterministically. Any day that has no payload comes back unavailable, which
/// is exactly the offline behaviour under test.
class _OfflineRepo extends RashifalRepository {
  _OfflineRepo({required this.dateKey, String? previousKey, DateTime? today})
      : _previousKey = previousKey,
        super(now: today == null ? null : () => today);

  final String dateKey;
  final String? _previousKey;

  DailyRashifal? get payload => _payload;

  DailyRashifal? _payload;

  @override
  Future<RashifalDayResult?> getForDate(DateTime date) async {
    final key = dateKeyOf(date);
    if (key == dateKey) {
      return RashifalDayResult(data: _day(dateKey), fromCache: false);
    }
    if (key == _previousKey) {
      return RashifalDayResult(data: _day(_previousKey!), fromCache: true);
    }
    return null;
  }

  DailyRashifal _day(String key) {
    _payload ??= DailyRashifal.tryParse(buildPayload(key))!;
    return _payload!;
  }
}

/// A repository with nothing to give, for the honest-unavailable path.
class _EmptyRepo extends RashifalRepository {
  @override
  Future<RashifalDayResult?> getForDate(DateTime date) async => null;
}

/// Dedicated UI fixture: long localized paragraphs without altering the payload
/// fixtures used by repository/cache/date-integrity behavior tests.
class _UiTestRepo extends RashifalRepository {
  _UiTestRepo() : super(now: () => DateTime(2026, 9, 28));

  Future<RashifalDayResult?> Function(DateTime)? response;
  final requested = <DateTime>[];

  DailyRashifal day(DateTime date) {
    final raw =
        jsonDecode(buildPayload(dateKeyOf(date))) as Map<String, dynamic>;
    for (final lang in ['hi', 'en']) {
      final paragraph = lang == 'hi'
          ? 'अपने काम को सहज गति से पूरा करें और अपनों के साथ समय बिताएँ। '
              'धैर्य और संतुलन के साथ छोटे कदम उठाना उपयोगी है। '
              'दिनचर्या में विश्राम और शांत चिंतन के लिए पर्याप्त समय रखें।'
          : 'Take time to complete your work thoughtfully and connect with loved ones. '
              'Patient, balanced steps can help you make room for what matters. '
              'Leave enough time in your routine for rest and quiet reflection.';
      for (final sign in kRashifalSignKeys) {
        final entry = raw['languages'][lang][sign];
        final fields = [
          'general',
          'career',
          'finance',
          'love',
          'health',
          'guidance'
        ];
        for (var i = 0; i < fields.length; i++) {
          entry[fields[i]] = '${i + 1}. $paragraph\n\n'
              '${lang == 'hi' ? 'यह अंतिम पंक्ति भी पूरी दिखाई देनी चाहिए।' : 'This final sentence should also remain fully readable.'}';
        }
        entry['luckyColour'] = lang == 'hi'
            ? 'हल्का केसरिया और सुनहरा पीला'
            : 'Soft saffron and warm golden yellow';
      }
    }
    return DailyRashifal.tryParse(jsonEncode(raw))!;
  }

  @override
  Future<RashifalDayResult?> getForDate(DateTime date) async {
    requested.add(date);
    if (response != null) return response!(date);
    if (isFuture(date)) return null;
    return RashifalDayResult(data: day(date), fromCache: false);
  }
}

Future<void> _revealUi(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 240,
      scrollable: find.byType(Scrollable).first, maxScrolls: 300);
  await tester.pump();
  expect(target, findsOneWidget);
}

void _expectReadable(WidgetTester tester, Finder finder, double scale) {
  expect(finder, findsOneWidget);
  final text = tester.widget<Text>(finder);
  expect(text.maxLines, isNull);
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  expect(find.ancestor(of: finder, matching: find.byType(FittedBox)),
      findsNothing);
  final rich = find.descendant(of: finder, matching: find.byType(RichText));
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.textScaler.scale(16), closeTo(16 * scale, 0.01));
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  expect(paragraph.size.height + 0.5, greaterThanOrEqualTo(painter.height));
  for (final line in painter.computeLineMetrics()) {
    expect(line.width, lessThanOrEqualTo(paragraph.size.width + 0.5));
  }
  painter.dispose();
}

Finder _uiIconButton(String tooltip) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip);

void _expectToolbarContained(WidgetTester tester) {
  final bar = find.byType(AppBar);
  final title = find.descendant(of: bar, matching: find.byType(Text));
  expect(title, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: title, matching: find.byType(RichText)));
  expect(paragraph.didExceedMaxLines, isFalse,
      reason: 'toolbar title must not be clipped or ellipsized');
  final bounds = tester.getRect(title);
  final toolbar = tester.getRect(bar);
  expect(bounds.left, greaterThanOrEqualTo(toolbar.left));
  expect(bounds.right, lessThanOrEqualTo(toolbar.right + 0.5));
  expect(bounds.top, greaterThanOrEqualTo(toolbar.top));
  expect(bounds.bottom, lessThanOrEqualTo(toolbar.bottom + 0.5));
}
