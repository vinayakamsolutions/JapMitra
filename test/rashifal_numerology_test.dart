import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/numerology/numerology_screen.dart';
import 'package:japmitra/features/numerology/numerology_service.dart';
import 'package:japmitra/features/rashifal/rashifal_model.dart';
import 'package:japmitra/features/rashifal/rashifal_screen.dart';
import 'package:japmitra/main.dart';

Future<AppState> _state({String language = 'hi'}) async {
  SharedPreferences.setMockInitialValues({'lang': language});
  final prefs = await SharedPreferences.getInstance();
  final st = AppState();
  st.prefs = prefs;
  st.languageCode = language;
  return st;
}

/// Mirrors `JapMitraAppState`: the whole tree is rebuilt whenever AppState
/// changes, which is what makes a chosen sign light up on every screen.
class _RevisionHost extends StatefulWidget {
  const _RevisionHost({required this.state, required this.builder});

  final AppState state;
  final WidgetBuilder builder;

  @override
  State<_RevisionHost> createState() => _RevisionHostState();
}

class _RevisionHostState extends State<_RevisionHost> {
  @override
  void initState() {
    super.initState();
    widget.state.revision.addListener(_onRevision);
  }

  @override
  void didUpdateWidget(covariant _RevisionHost old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.revision.removeListener(_onRevision);
      widget.state.revision.addListener(_onRevision);
    }
  }

  @override
  void dispose() {
    widget.state.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _wrap({
  required AppState state,
  required Widget Function() home,
  Locale locale = const Locale('hi'),
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    _RevisionHost(
      state: state,
      builder: (context) => MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('hi'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: InheritedAppState(state: state, child: child!),
        ),
        home: home(),
      ),
    );

/// Runs [body] and returns every framework error it raised, so a test can assert
/// on the absence of exceptions as well as on rendered content.
Future<List<String>> _errorsDuring(Future<void> Function() body) async {
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

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder get _list => find.byType(Scrollable).first;

/// Drags the list back to the start, so a following [_scrollTo] only ever has to
/// search downwards. Lazy lists unmount whatever is far off screen, so an element
/// above the current offset has to be scrolled to from the top.
Future<void> _scrollToTop(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.drag(_list, const Offset(0, 3000));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Scrolls down the whole list, so an absence assertion covers every row and not
/// just the ones that happen to be built.
Future<void> _scrollToBottom(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(_list, const Offset(0, -3000));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Makes [target] built and fully visible, searching from the top of the list.
///
/// The list offset survives a `pumpWidget` of the same screen type, so every
/// search starts from the top: an element above the current offset has to be
/// scrolled back to, and a lazy list has not even built it yet.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await _scrollToTop(tester);
  if (target.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(target, 200,
          scrollable: _list, maxScrolls: 60);
    } catch (_) {
      // Not reachable with the framework helper; the plain drags below retry.
    }
  }
  for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
    await tester.drag(_list, const Offset(0, -200));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(target, findsWidgets, reason: 'could not scroll to $target');
  await Scrollable.ensureVisible(tester.element(target.first),
      duration: Duration.zero);
  await tester.pumpAndSettle();
}

/// Asserts that the result card titled [title] shows [value], tying the value to
/// its own row so two rows cannot satisfy each other.
Future<void> _expectResultRow(
  WidgetTester tester,
  String title,
  String value,
) async {
  await _scrollTo(tester, find.text(title));
  final card = find.ancestor(of: find.text(title), matching: find.byType(Card));
  expect(card, findsOneWidget, reason: 'no result card titled "$title"');
  expect(
    find.descendant(of: card, matching: find.text(value)),
    findsOneWidget,
    reason: '"$title" should show $value',
  );
}

/// The tile for one zodiac sign, identified by its unique glyph.
///
/// A sign's name also appears in the "my sign" card at the top of the list, so
/// the name alone is ambiguous; the glyph belongs only to its own tile.
Finder _signTile(String glyph) =>
    find.ancestor(of: find.text(glyph), matching: find.byType(ListTile));

void main() {
  group('NumerologyService', () {
    final service = NumerologyService();

    test('reduces any number to a single digit', () {
      expect(service.digitSum(9), 9);
      // 19 -> 1 + 9 = 10 -> 1 + 0 = 1
      expect(service.digitSum(19), 1);
      // 1 + 5 + 5 + 1 + 9 + 9 + 0 = 30 -> 3
      expect(service.digitSum(1990515), 3);
      expect(() => service.digitSum(-1), throwsArgumentError);
    });

    test('derives birth number from the day of birth alone', () {
      // 15 -> 1 + 5 = 6
      expect(service.birthNumber(DateTime(1990, 5, 15)), 6);
      // 29 -> 2 + 9 = 11 -> 1 + 1 = 2
      expect(service.birthNumber(DateTime(1990, 12, 29)), 2);
    });

    test('derives life path from the full date of birth', () {
      // 15/5/1990 -> 1 + 5 + 5 + 1 + 9 + 9 + 0 = 30 -> 3
      expect(service.lifePathNumber(DateTime(1990, 5, 15)), 3);
    });

    test("derives today's number from the requested date", () {
      // 9 + 3 + 2024 = 2036 -> 2 + 0 + 3 + 6 = 11 -> 2
      expect(service.todayNumber(DateTime(2024, 3, 9)), 2);
      // 19 + 3 + 2024 = 2046 -> 2 + 0 + 4 + 6 = 12 -> 3
      expect(service.todayNumber(DateTime(2024, 3, 19)), 3);
    });

    test('insight is deterministic and derives every number itself', () {
      final a =
          service.insight(DateTime(1990, 5, 15), day: DateTime(2024, 3, 9));
      final b =
          service.insight(DateTime(1990, 5, 15), day: DateTime(2024, 3, 9));
      expect(a.birthNumber, b.birthNumber);
      expect(a.lifePathNumber, b.lifePathNumber);
      expect(a.todayNumber, b.todayNumber);
      expect(a.luckyNumber, b.luckyNumber);
      expect(a.birthNumber, 6);
      expect(a.lifePathNumber, 3);
      expect(a.todayNumber, 2);
      // The lucky number is derived, not looked up from the date.
      expect(a.luckyNumber, service.digitSum(a.birthNumber + a.todayNumber));
      expect(a.luckyNumber, 8);
    });

    test('the same date always gives the same reading', () {
      final a =
          service.insight(DateTime(1988, 8, 8), day: DateTime(2024, 3, 1));
      final b =
          service.insight(DateTime(1988, 8, 8), day: DateTime(2024, 3, 1));
      expect(a.luckyColour, b.luckyColour);
      expect(a.dailyGuidance, b.dailyGuidance);
    });

    test('each lucky number always carries the same colour and guidance', () {
      final colours = <int, String>{};
      final guidance = <int, String>{};
      for (var day = 1; day <= 28; day++) {
        for (var month = 1; month <= 12; month++) {
          for (final when in [DateTime(2024, 1, 1), DateTime(2024, 5, 20)]) {
            final insight = service.insight(
              DateTime(1990, month, day),
              day: when,
            );
            final lucky = insight.luckyNumber;
            expect(lucky, inInclusiveRange(1, 9));
            expect(insight.luckyColour.trim(), isNotEmpty);
            expect(insight.dailyGuidance.trim(), isNotEmpty);
            if (colours.containsKey(lucky)) {
              expect(colours[lucky], insight.luckyColour,
                  reason: 'colour for number $lucky changed');
              expect(guidance[lucky], insight.dailyGuidance,
                  reason: 'guidance for number $lucky changed');
            }
            colours[lucky] = insight.luckyColour;
            guidance[lucky] = insight.dailyGuidance;
          }
        }
      }
      // All nine numbers are reachable from real dates.
      expect(colours.keys.toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9});
    });

    test('rejects a future date of birth and one out of range', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(() => service.validateDob(tomorrow), throwsArgumentError);
      expect(() => service.validateDob(DateTime(1899, 12, 31)),
          throwsArgumentError);
      expect(() => service.insight(tomorrow), throwsArgumentError);
    });
  });

  group('RashifalRepository', () {
    test('never hands back unverified content as a reading', () async {
      const repository = RashifalRepository();
      for (final sign in signs) {
        final content = await repository.getToday(sign[0]);
        expect(content.signKey, sign[0]);
        expect(content.isVerified, isFalse);
        expect(content.hasContent, isFalse);
        expect(content.general, isNull);
        expect(content.career, isNull);
        expect(content.finance, isNull);
        expect(content.relationships, isNull);
        expect(content.health, isNull);
        expect(content.luckyNumber, isNull);
        expect(content.luckyColour, isNull);
        expect(content.dailyGuidance, isNull);
      }
    });
  });

  group('Rashifal screen', () {
    testWidgets('lists all twelve signs in both scripts and both languages',
        (tester) async {
      _useViewport(tester, const Size(360, 640));

      for (final locale in const [Locale('hi'), Locale('en')]) {
        final l = AppLocalizations(locale);
        final state = await _state(language: locale.languageCode);
        await tester.pumpWidget(_wrap(
          state: state,
          locale: locale,
          home: () => const RashifalScreen(),
        ));
        await tester.pumpAndSettle();

        // Nothing is chosen yet, so the prompt is offered up front.
        await _scrollToTop(tester);
        expect(find.text(l.t('myRashi')), findsOneWidget);
        expect(find.text(l.t('rashiNotSetNote')), findsOneWidget);
        expect(find.text(l.t('rashifal')), findsWidgets);

        for (final sign in signs) {
          await _scrollTo(tester, find.text('${sign[1]} / ${sign[2]}'));
          expect(find.text('${sign[1]} / ${sign[2]}'), findsOneWidget,
              reason: '${sign[0]} in $locale');
        }
        expect(find.byType(RashiDetail), findsNothing);
      }
    });

    testWidgets('persists the chosen sign, marks it mine, and clears it',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('en'));
      final state = await _state(language: 'en');
      await tester.pumpWidget(_wrap(
        state: state,
        locale: const Locale('en'),
        home: () => const RashifalScreen(),
      ));
      await tester.pumpAndSettle();

      await _scrollToTop(tester);
      expect(find.text(l.t('rashiNotSetNote')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      final sign = signs[4];
      await _scrollTo(tester, find.text('${sign[1]} / ${sign[2]}'));
      await tester.tap(find.text('${sign[1]} / ${sign[2]}'));
      await tester.pumpAndSettle();

      // Persisted, and readable by a fresh state.
      expect(state.rashiSign, sign[0]);
      expect(state.prefs.getString('rashiSign'), sign[0]);
      final restored = AppState();
      await restored.load();
      expect(restored.rashiSign, sign[0]);

      // The detail page marks it as mine.
      expect(find.byType(RashiDetail), findsOneWidget);
      expect(find.text(l.t('myRashi')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // The tile is highlighted and the top card is no longer a prompt.
      expect(find.text(l.t('rashiNotSetNote')), findsNothing);
      final tile = _signTile(sign[3]);
      await _scrollTo(tester, find.text(sign[3]));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );

      await _scrollToTop(tester);
      await tester.tap(find.byTooltip(l.t('clearMySign')));
      await tester.pumpAndSettle();
      expect(state.rashiSign, isNull);
      expect(state.prefs.getString('rashiSign'), isNull);
      expect(find.text(l.t('rashiNotSetNote')), findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.check_circle)),
        findsNothing,
      );
    });

    testWidgets('detail page names the sign and admits the reading is absent',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('en'));
      final state = await _state(language: 'en');
      await tester.pumpWidget(_wrap(
        state: state,
        locale: const Locale('en'),
        home: () => const RashifalScreen(),
      ));
      await tester.pumpAndSettle();

      final sign = signs[1];
      await _scrollTo(tester, find.text('${sign[1]} / ${sign[2]}'));
      await tester.tap(find.text('${sign[1]} / ${sign[2]}'));
      await tester.pumpAndSettle();

      // Pushed onto its own route.
      expect(find.byType(RashiDetail), findsOneWidget);
      expect(find.text('${sign[1]} / ${sign[2]}'), findsWidgets);
      expect(find.text(l.t('unavailable')), findsOneWidget);
      expect(find.text(l.t('rashifalUnavailableNote')), findsWidgets);

      // No prediction row is rendered while the content is unverified.
      await _scrollToBottom(tester);
      for (final row in [
        l.t('general'),
        l.t('career'),
        l.t('finance'),
        l.t('relationships'),
        l.t('health'),
        l.t('luckyNumber'),
        l.t('luckyColour'),
        l.t('dailyGuidance'),
      ]) {
        expect(find.text(row), findsNothing,
            reason: '"$row" would imply a reading');
      }
      expect(find.text(l.t('unavailable')), findsOneWidget);
    });

    testWidgets('no configured source means no prediction text at all',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setRashiSign(signs[0][0]);
      await tester
          .pumpWidget(_wrap(state: state, home: () => const RashifalScreen()));
      await tester.pumpAndSettle();

      // The stored sign is picked up as "mine" without any reading.
      await _scrollToTop(tester);
      expect(find.text(l.t('rashiNotSetNote')), findsNothing);

      await _scrollTo(tester, find.text(signs[0][3]));
      await tester.tap(_signTile(signs[0][3]));
      await tester.pumpAndSettle();

      await _scrollToBottom(tester);
      for (final row in [
        l.t('general'),
        l.t('career'),
        l.t('finance'),
        l.t('relationships'),
        l.t('health'),
        l.t('luckyNumber'),
        l.t('luckyColour'),
        l.t('dailyGuidance'),
      ]) {
        expect(find.text(row), findsNothing, reason: row);
      }
      expect(find.text(l.t('unavailable')), findsOneWidget);
      expect(find.text(l.t('guidanceOnly')), findsWidgets);
    });

    testWidgets('lays out without overflow at 2x text on a 320x480 screen',
        (tester) async {
      _useViewport(tester, const Size(320, 480));
      final state = await _state();
      final errors = await _errorsDuring(() async {
        await tester.pumpWidget(_wrap(
          state: state,
          home: () => const RashifalScreen(),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();
        for (final sign in signs) {
          await _scrollTo(tester, find.text('${sign[1]} / ${sign[2]}'));
        }
      });
      expect(errors, isEmpty);
    });
  });

  group('Numerology screen', () {
    testWidgets('shows no numbers until a date of birth is set',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await tester.pumpWidget(
          _wrap(state: state, home: () => const NumerologyScreen()));
      await tester.pumpAndSettle();

      expect(find.text(l.t('notSci')), findsOneWidget);
      expect(find.text(l.t('calculateNumerology')), findsOneWidget);
      // Nothing is prefilled, so no result row exists anywhere in the list.
      await _scrollToBottom(tester);
      for (final label in [
        l.t('birthNumber'),
        l.t('lifePath'),
        l.t('todayNumber'),
        l.t('luckyNumber'),
        l.t('luckyColour'),
        l.t('dailyGuidance'),
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text(l.t('deleteDob')), findsNothing);
    });

    testWidgets('calculates every number from the stored date of birth',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setDob(DateTime(1990, 5, 15));
      await tester.pumpWidget(
          _wrap(state: state, home: () => const NumerologyScreen()));
      await tester.pumpAndSettle();

      // The disclaimer is on screen before anything is scrolled away.
      expect(find.text(l.t('notSci')), findsOneWidget);

      final expected = NumerologyService()
          .insight(DateTime(1990, 5, 15), day: DateTime.now());

      // The stored date is shown, and every number is derived from it.
      expect(find.textContaining('15/5/1990'), findsOneWidget);
      await _expectResultRow(
          tester, l.t('birthNumber'), '${expected.birthNumber}');
      await _expectResultRow(
          tester, l.t('lifePath'), '${expected.lifePathNumber}');
      await _expectResultRow(
          tester, l.t('todayNumber'), '${expected.todayNumber}');
      await _expectResultRow(
          tester, l.t('luckyNumber'), '${expected.luckyNumber}');
      await _expectResultRow(tester, l.t('luckyColour'), expected.luckyColour);
      await _expectResultRow(
          tester, l.t('dailyGuidance'), expected.dailyGuidance);

      // Associations are labelled as tradition, not as prediction.
      expect(find.text(l.t('traditionalNote')), findsWidgets);
    });

    testWidgets('recalculating gives the same reading for the same date',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setDob(DateTime(1990, 5, 15));
      await tester.pumpWidget(
          _wrap(state: state, home: () => const NumerologyScreen()));
      await tester.pumpAndSettle();

      final expected = NumerologyService()
          .insight(DateTime(1990, 5, 15), day: DateTime.now());

      await _scrollTo(tester, find.text(l.t('calculateNumerology')));
      await tester.tap(find.text(l.t('calculateNumerology')));
      await tester.pumpAndSettle();

      await _expectResultRow(
          tester, l.t('birthNumber'), '${expected.birthNumber}');
      await _expectResultRow(tester, l.t('luckyColour'), expected.luckyColour);
    });

    testWidgets(
        'a stored future date of birth produces no numbers and no crash',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      // Saved while the device clock was wrong, so a future date got persisted.
      await state.setDob(DateTime.now().add(const Duration(days: 400)));

      final errors = await _errorsDuring(() async {
        await tester.pumpWidget(
            _wrap(state: state, home: () => const NumerologyScreen()));
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
      expect(find.text(l.t('birthNumber')), findsNothing);

      // Asking for a reading explains the problem instead of guessing.
      await _scrollTo(tester, find.text(l.t('calculateNumerology')));
      await tester.tap(find.text(l.t('calculateNumerology')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(l.t('birthNumber')), findsNothing);
    });

    testWidgets('a stored date outside the supported range is handled',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setDob(DateTime(1800, 1, 1));

      final errors = await _errorsDuring(() async {
        await tester.pumpWidget(
            _wrap(state: state, home: () => const NumerologyScreen()));
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text(l.t('calculateNumerology')));
        await tester.tap(find.text(l.t('calculateNumerology')));
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
      expect(find.text(l.t('lifePath')), findsNothing);
    });

    testWidgets('clearing the date of birth removes the reading',
        (tester) async {
      _useViewport(tester, const Size(360, 640));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setDob(DateTime(1990, 5, 15));
      await tester.pumpWidget(
          _wrap(state: state, home: () => const NumerologyScreen()));
      await tester.pumpAndSettle();

      await _expectResultRow(tester, l.t('birthNumber'), '6');

      await _scrollTo(tester, find.text(l.t('deleteDob')));
      await tester.tap(find.text(l.t('deleteDob')));
      await tester.pumpAndSettle();

      expect(state.dob, isNull);
      expect(state.prefs.getString('dob'), isNull);
      expect(find.text(l.t('birthNumber')), findsNothing);
      expect(find.text(l.t('deleteDob')), findsNothing);
    });

    testWidgets('lays out without overflow at 2x text on a 320x480 screen',
        (tester) async {
      _useViewport(tester, const Size(320, 480));
      final l = AppLocalizations(const Locale('hi'));
      final state = await _state();
      await state.setDob(DateTime(1990, 5, 15));
      final errors = await _errorsDuring(() async {
        await tester.pumpWidget(_wrap(
          state: state,
          home: () => const NumerologyScreen(),
          textScaler: const TextScaler.linear(2.0),
        ));
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text(l.t('dailyGuidance')));
        expect(find.text(l.t('dailyGuidance')), findsOneWidget);
      });
      expect(errors, isEmpty);
    });
  });
}
