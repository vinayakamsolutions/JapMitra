import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/home/home_screen.dart';
import 'package:japmitra/features/panchang/panchang_screen.dart';
import 'package:japmitra/features/settings/more_screen.dart';
import 'package:japmitra/main.dart';

/// The three viewports the app has to survive, smallest first.
const _sizes = [Size(320, 480), Size(360, 640), Size(411, 731)];

/// A 1.5x system font setting is a realistic accessibility choice and the point
/// where fixed-height rows start to break.
const _largeText = TextScaler.linear(1.5);

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<AppState> _state({String language = 'hi'}) async {
  SharedPreferences.setMockInitialValues({'lang': language});
  final prefs = await SharedPreferences.getInstance();
  final s = AppState();
  s.prefs = prefs;
  s.languageCode = language;
  return s;
}

Widget _app({
  required AppState state,
  required Widget child,
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
          home: child,
        ),
      ),
    );

/// Runs [body] and returns every framework exception it raised, so a test can
/// assert "no overflow, no crash" rather than only that nothing was thrown.
Future<List<String>> _collectErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final errors = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    // A RenderFlex overflow is a layout bug, not a test artefact.
    if (!text.contains('A Timer was still pending')) errors.add(text);
  };
  try {
    await body();
    await tester.pump(const Duration(milliseconds: 50));
  } finally {
    FlutterError.onError = prev;
  }
  return errors;
}

void main() {
  group('Home screen is responsive', () {
    for (final size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        _useViewport(tester, size);

        final errors = await _collectErrors(tester, () async {
          await tester.pumpWidget(
              _app(state: await _state(), child: const HomeScreen()));
          await tester.pump(const Duration(milliseconds: 50));
        });

        expect(errors, isEmpty);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    }

    testWidgets('survives large text without overflowing', (tester) async {
      _useViewport(tester, const Size(320, 480));

      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(_app(
          state: await _state(),
          textScaler: _largeText,
          child: const HomeScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 50));
      });

      expect(errors, isEmpty);
    });

    testWidgets('scrolls to its last card on the smallest screen',
        (tester) async {
      _useViewport(tester, const Size(320, 480));
      await tester
          .pumpWidget(_app(state: await _state(), child: const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // The screen is a list, so nothing may be unreachable off the bottom.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('More screen is responsive', () {
    for (final size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        _useViewport(tester, size);

        final errors = await _collectErrors(tester, () async {
          await tester.pumpWidget(
              _app(state: await _state(), child: const MoreScreen()));
          await tester.pump(const Duration(milliseconds: 50));
        });

        expect(errors, isEmpty);
        expect(find.byType(MoreScreen), findsOneWidget);
      });
    }

    testWidgets('survives large text without overflowing', (tester) async {
      _useViewport(tester, const Size(320, 480));

      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(_app(
          state: await _state(),
          textScaler: _largeText,
          child: const MoreScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 50));
      });

      expect(errors, isEmpty);
    });
  });

  group('Panchang calendar is responsive', () {
    for (final size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        _useViewport(tester, size);

        final errors = await _collectErrors(tester, () async {
          await tester.pumpWidget(_app(
            state: await _state(),
            child: PanchangScreen(initialMonth: _october2026),
          ));
          // The month is calculated asynchronously, so give it a few frames.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
        });

        expect(errors, isEmpty);
        expect(find.byType(PanchangScreen), findsOneWidget);
      });
    }

    testWidgets('the grid still shows a full week of days when narrow',
        (tester) async {
      _useViewport(tester, const Size(320, 480));
      await tester.pumpWidget(_app(
        state: await _state(language: 'en'),
        locale: const Locale('en'),
        child: PanchangScreen(initialMonth: _october2026),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // English avoids non-ASCII literals here; the point is that the header,
      // the grid and the inline detail all still fit on the narrowest screen.
      final l = AppLocalizations(const Locale('en'));
      expect(find.text(l.t('tithi')), findsOneWidget);
      expect(find.text(l.t('viewFullPanchang')), findsOneWidget);
      expect(find.textContaining('Ashwin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives large text without overflowing', (tester) async {
      _useViewport(tester, const Size(320, 480));

      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(_app(
          state: await _state(),
          textScaler: _largeText,
          child: PanchangScreen(initialMonth: _october2026),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      });

      expect(errors, isEmpty);
    });
  });
}

/// A fixed month keeps the calendar deterministic regardless of when the suite
/// runs. October 2026 has 31 days and straddles the Ashwin -> Kartika ingress.
final DateTime _october2026 = DateTime(2026, 10);
