import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/data/local/jap_store.dart';
import 'package:japmitra/data/repositories/jap_repository.dart';
import 'package:japmitra/features/jap/jap_screen.dart';
import 'package:japmitra/main.dart';

/// In-memory [JapStore] so these tests exercise the real repository and the
/// real debounced queue, with no sqflite binding.
class MemStore implements JapStore {
  final List<MapEntry<String, JapEventRow>> rows = [];

  int totalFor(String mantra) {
    var sum = 0;
    for (final r in rows) {
      if (r.key == mantra) sum += r.value.count;
    }
    return sum;
  }

  @override
  Future<void> insertEvent(String mantra, int count, DateTime at) async =>
      rows.add(MapEntry(mantra, JapEventRow(count: count, at: at)));

  @override
  Future<int> sumSince(String mantra, DateTime start, {DateTime? end}) async {
    var s = 0;
    for (final r in rows) {
      if (r.key == mantra && !r.value.at.isBefore(start)) {
        if (end == null || r.value.at.isBefore(end)) s += r.value.count;
      }
    }
    return s;
  }

  @override
  Future<int> sumAll() async {
    var s = 0;
    for (final r in rows) {
      s += r.value.count;
    }
    return s;
  }

  @override
  Future<void> deleteSince(String mantra, DateTime start,
          {DateTime? end}) async =>
      rows.removeWhere((r) =>
          r.key == mantra &&
          !r.value.at.isBefore(start) &&
          (end == null || r.value.at.isBefore(end)));

  @override
  Future<List<JapEventRow>> events(String mantra,
          {DateTime? start, DateTime? end}) async =>
      rows
          .where((r) =>
              r.key == mantra &&
              (start == null || !r.value.at.isBefore(start)) &&
              (end == null || r.value.at.isBefore(end)))
          .map((r) => r.value)
          .toList();

  @override
  Future<List<String>> listCustomMantras() async => [];

  @override
  Future<void> addCustomMantra(String text) async {}

  @override
  Future<void> removeCustomMantra(String text) async {}
}

Future<AppState> _appState(
    {String language = 'hi', String mantra = 'ॐ नमः शिवाय'}) async {
  SharedPreferences.setMockInitialValues({'lang': language});
  final prefs = await SharedPreferences.getInstance();
  final st = AppState();
  st.prefs = prefs;
  st.languageCode = language;
  st.selectedMantra = mantra;
  return st;
}

Widget _app({
  required AppState state,
  required JapRepository repo,
  Locale locale = const Locale('hi'),
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: InheritedAppState(
        state: state,
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('hi'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: JapScreen(repository: repo),
        ),
      ),
    );

/// Collects every framework exception raised while [body] runs, so a test can
/// assert "no overflow, no crash" instead of only checking it did not throw.
Future<List<String>> _collectErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError =
      (details) => errors.add(details.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  group('Jap screen layout', () {
    const viewports = <Size>[Size(320, 480), Size(360, 640), Size(411, 731)];
    const scales = <double>[1.0, 1.3, 2.0];

    for (final size in viewports) {
      for (final scale in scales) {
        testWidgets(
            'lays out without overflow on ${size.width.toInt()}x${size.height.toInt()} at text scale $scale',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final store = MemStore();
          // A six digit lifetime total is the case that used to blow the stats
          // row out to the right by 216 pixels.
          store.rows.add(MapEntry(
              'ॐ नमः शिवाय', JapEventRow(count: 1234567, at: DateTime(2020))));
          store.rows.add(MapEntry(
              'ॐ नमः शिवाय', JapEventRow(count: 216, at: DateTime.now())));

          final state = await _appState();
          final errors = await _collectErrors(tester, () async {
            await tester.pumpWidget(_app(
              state: state,
              repo: JapRepository(store: store),
              textScaler: TextScaler.linear(scale),
            ));
            await tester.pump(const Duration(milliseconds: 50));
          });

          expect(errors, isEmpty, reason: 'layout errors on $size @ $scale');
          expect(find.byKey(const Key('jap_counter')), findsOneWidget);
        });
      }
    }

    testWidgets('hides the layout safely behind a huge text scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _appState();
      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(_app(
          state: state,
          repo: JapRepository(store: MemStore()),
          textScaler: const TextScaler.linear(3.5),
        ));
        await tester.pump(const Duration(milliseconds: 50));
      });

      expect(errors, isEmpty);
    });
  });

  group('Jap screen counting', () {
    testWidgets('every pointer down counts exactly one Jap', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _appState();
      await tester.pumpWidget(
          _app(state: state, repo: JapRepository(store: MemStore())));
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 1; i <= 20; i++) {
        await tester.tapAt(const Offset(200, 500));
        await tester.pump();
        expect(_counter(tester), '$i', reason: 'tap #$i');
      }
    });

    testWidgets('a rapid burst is not dropped', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _appState();
      await tester.pumpWidget(
          _app(state: state, repo: JapRepository(store: MemStore())));
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 50; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      await tester.pump();

      expect(_counter(tester), '50');

      // The queue batches the burst into a single write, and loses nothing.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(find.byKey(const Key('jap_mala_label')), findsOneWidget);
    });

    testWidgets('a burst is persisted as one batched row', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = MemStore();
      final state = await _appState();
      await tester
          .pumpWidget(_app(state: state, repo: JapRepository(store: store)));
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 30; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      expect(store.rows, isEmpty, reason: 'writes are debounced, not per tap');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(store.rows.length, 1);
      expect(store.rows.single.value.count, 30);
      expect(_counter(tester), '30');
    });

    testWidgets('the 108th tap counts, completes a mala and resets progress',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = MemStore();
      final state = await _appState();
      await tester
          .pumpWidget(_app(state: state, repo: JapRepository(store: store)));
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 107; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      await tester.pump();
      expect(_counter(tester), '107');
      expect(_malaText(tester), contains('107/108'));
      expect(_completedMalas(tester), contains('0'));

      await tester.tapAt(const Offset(200, 500));
      await tester.pump();

      // The boundary itself is counted, and the current mala restarts at 0.
      expect(_counter(tester), '108');
      expect(_malaText(tester), contains('1  •  0/108'));
      expect(_completedMalas(tester), contains('1'));
      expect(find.textContaining('पूर्ण हुई'), findsOneWidget,
          reason: 'completion feedback is shown');

      // And it is persisted, not just displayed.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(store.totalFor('ॐ नमः शिवाय'), 108);
    });

    testWidgets('a new session starts clean but keeps the stored total',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = MemStore();
      final state = await _appState();
      await tester
          .pumpWidget(_app(state: state, repo: JapRepository(store: store)));
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 12; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(_counter(tester), '12');
      expect(store.totalFor('ॐ नमः शिवाय'), 12);

      // Leave the screen entirely, then come back to it.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 700));
      await tester
          .pumpWidget(_app(state: state, repo: JapRepository(store: store)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // The session counter is fresh, and today still carries the 12 taps.
      expect(_counter(tester), '0');
      expect(_todayValue(tester), '12',
          reason: 'store rows: ${store.rows.length}');
      expect(store.totalFor('ॐ नमः शिवाय'), 12);
    });

    testWidgets('today reflects the live session and does not double count',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = MemStore();
      final state = await _appState();
      await tester
          .pumpWidget(_app(state: state, repo: JapRepository(store: store)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_todayValue(tester), '0');

      for (var i = 0; i < 5; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      await tester.pump();
      expect(_todayValue(tester), '5', reason: 'live, before any flush');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(_todayValue(tester), '5',
          reason: 'still 5 after the batched write');

      for (var i = 0; i < 3; i++) {
        await tester.tapAt(const Offset(200, 500));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(_todayValue(tester), '8');
      expect(store.totalFor('ॐ नमः शिवाय'), 8);
    });
  });

  group('Jap screen chrome', () {
    testWidgets('the menu is reachable, so its actions are usable',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _appState();
      await tester.pumpWidget(
          _app(state: state, repo: JapRepository(store: MemStore())));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('मंत्र चुनें'), findsOneWidget);
      expect(find.text('Jap सत्र समाप्त करें?'), findsOneWidget);
      expect(find.text('रीसेट'), findsOneWidget);
    });

    testWidgets('tap glows are decoration: they neither eat nor block taps',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _appState();
      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(
            _app(state: state, repo: JapRepository(store: MemStore())));
        await tester.pump(const Duration(milliseconds: 50));
        for (var i = 0; i < 12; i++) {
          await tester.tapAt(const Offset(200, 400));
          await tester.pump(const Duration(milliseconds: 40));
        }
      });

      expect(errors, isEmpty);
      expect(_counter(tester), '12');
    });
  });
}

String _counter(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jap_counter'))).data!;

String _todayValue(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jap_today'))).data!;

String _malaText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jap_mala_label'))).data!;

String _completedMalas(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jap_mala_completed'))).data!;
