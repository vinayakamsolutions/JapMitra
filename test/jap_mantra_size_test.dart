import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/data/repositories/jap_repository.dart';
import 'package:japmitra/features/jap/deity_background.dart';
import 'package:japmitra/features/jap/jap_screen.dart';
import 'package:japmitra/features/jap/tap_visual.dart';
import 'package:japmitra/features/settings/more_screen.dart';
import 'package:japmitra/main.dart';

import 'jap_screen_test.dart' show MemStore;

/// Builds a fully wired app around the Jap screen with a fresh in-memory store.
Future<(AppState, JapRepository)> _state() async {
  SharedPreferences.setMockInitialValues({'lang': 'hi'});
  final prefs = await SharedPreferences.getInstance();
  final st = AppState();
  st.prefs = prefs;
  st.languageCode = 'hi';
  return (st, JapRepository(store: MemStore()));
}

/// Mirrors `JapMitraAppState`: the real app listens to [AppState.revision] and
/// rebuilds on every mutation, which is what propagates a setting change to
/// whichever screen is mounted. A test harness that skipped this would not be
/// testing the behaviour the user sees.
class _RevisionHost extends StatefulWidget {
  const _RevisionHost({required this.state, required this.builder});

  final AppState state;

  /// Builds the tree under test, so every rebuild creates fresh widgets just
  /// as the real app's `setState` does.
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
    // The revision host sits above the MaterialApp, exactly like
    // `JapMitraAppState` in the real app: one rebuild re-creates the whole
    // tree below it, so every screen re-reads AppState.
    _RevisionHost(
      state: state,
      builder: (_) => MediaQuery(
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
            home: home(),
          ),
        ),
      ),
    );

/// Scrolls the settings list until [target] is on screen, so tiles below the
/// fold are built and tappable.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

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

/// The font size the setting actually applies to the mantra text.
double _renderedMantraSize(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('jap_mantra_name')));
  final size = text.style?.fontSize;
  expect(size, isNotNull, reason: 'the mantra must use an explicit size');
  return size!;
}

const _dev = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
String _toDev(int n) {
  if (n == 0) return _dev[0];
  final buf = StringBuffer();
  var v = n;
  while (v > 0) {
    buf.write(_dev[v % 10]);
    v ~/= 10;
  }
  return buf.toString().split('').reversed.join();
}

/// The live tap counter as the user sees it.
String _counter(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('jap_counter'))).data!;

void main() {
  group('Mantra font size setting', () {
    test('is persisted, validated and restored', () async {
      SharedPreferences.setMockInitialValues({'lang': 'hi'});
      final prefs = await SharedPreferences.getInstance();
      final st = AppState();
      st.prefs = prefs;

      expect(st.mantraFontSize, kMantraFontSizes[kDefaultMantraFontSizeIndex]);

      await st.setMantraFontSizeIndex(3);
      expect(st.mantraFontSize, 44);

      // An out of range index can never produce an out of range size.
      await st.setMantraFontSizeIndex(99);
      expect(st.mantraFontSizeIndex, kMantraFontSizes.length - 1);
      await st.setMantraFontSizeIndex(-5);
      expect(st.mantraFontSizeIndex, 0);

      // A fresh state reads the stored choice back.
      final restored = AppState();
      await restored.load();
      expect(restored.mantraFontSizeIndex, 0);
    });

    testWidgets('is applied to the mantra on the Jap screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final (state, repo) = await _state();
      await tester.pumpWidget(
          _wrap(state: state, home: () => JapScreen(repository: repo)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_renderedMantraSize(tester),
          kMantraFontSizes[kDefaultMantraFontSizeIndex]);

      // Changing the setting takes effect immediately, without a restart.
      await state.setMantraFontSizeIndex(0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_renderedMantraSize(tester), kMantraFontSizes[0]);

      await state.setMantraFontSizeIndex(3);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_renderedMantraSize(tester), kMantraFontSizes[3]);
    });

    for (final locale in const [Locale('hi'), Locale('en')]) {
      testWidgets('offers every preset in settings, in $locale',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (state, _) = await _state();
        await tester.pumpWidget(_wrap(
          state: state,
          locale: locale,
          home: () => const MoreScreen(),
        ));
        await tester.pumpAndSettle();

        final l = AppLocalizations(locale);
        for (final label in [
          l.t('sizeSmall'),
          l.t('sizeMedium'),
          l.t('sizeLarge'),
          l.t('sizeExtraLarge'),
        ]) {
          await _scrollTo(tester, find.text(label));
          expect(find.text(label), findsOneWidget, reason: label);
        }
        await _scrollTo(tester, find.text(l.t('mantraFontSizeNote')));
        expect(find.text(l.t('mantraFontSizeNote')), findsOneWidget);
      });
    }

    testWidgets('a settings tap updates the stored size', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final (state, _) = await _state();
      await tester
          .pumpWidget(_wrap(state: state, home: () => const MoreScreen()));
      await tester.pumpAndSettle();

      final l = AppLocalizations(const Locale('hi'));
      await _scrollTo(tester, find.text(l.t('sizeExtraLarge')));
      await tester.tap(find.text(l.t('sizeExtraLarge')));
      await tester.pumpAndSettle();

      expect(state.mantraFontSizeIndex, kMantraFontSizes.length - 1);
      expect(state.prefs.getInt('mantraFontSizeIndex'),
          kMantraFontSizes.length - 1);
    });

    testWidgets('never changes the stored count', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final (state, repo) = await _state();
      await tester.pumpWidget(
          _wrap(state: state, home: () => JapScreen(repository: repo)));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap a few times, then change only the font size.
      for (var i = 0; i < 5; i++) {
        await tester.tapAt(const Offset(180, 300));
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pump(const Duration(milliseconds: 100));
      final before = _counter(tester);
      expect(before, _toDev(5));

      await state.setMantraFontSizeIndex(3);
      await tester.pump(const Duration(milliseconds: 100));

      expect(_counter(tester), before);
    });

    testWidgets('larger sizes stay inside the screen at extreme text scales',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final (state, repo) = await _state();
      final longMantras = <String>[
        'ॐ नमः शिवाय',
        'ॐ नमो भगवते वासुदेवाय',
        'oṃ namaḥ śivāya oṃ namo bhagavate vāsudevāya',
        'हरे कृष्ण हरे कृष्ण हरे कृष्ण हरे राम हरे राम हरे कृष्ण',
      ];
      for (final mantra in longMantras) {
        for (final index in [0, 3]) {
          for (final scale in [1.0, 2.0, 3.5]) {
            state.selectedMantra = mantra;
            await state.setMantraFontSizeIndex(index);
            final errors = await _collectErrors(tester, () async {
              await tester.pumpWidget(_wrap(
                state: state,
                home: () => JapScreen(repository: repo),
                textScaler: TextScaler.linear(scale),
              ));
              await tester.pump(const Duration(milliseconds: 30));
            });
            expect(errors, isEmpty,
                reason: 'overflow for "$mantra" size $index @ $scale');
            expect(find.byKey(const Key('jap_mantra_name')), findsOneWidget);
          }
        }
      }
    });
  });

  group('Tap feedback', () {
    testWidgets('shows the mantra, never the count', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var done = false;
      await tester.pumpWidget(_wrap(
        state: (await _state()).$1,
        home: () => MaterialApp(
          home: Scaffold(
            body: GoldenTapGlow(
              mantra: 'ॐ नमः शिवाय',
              onDone: () => done = true,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final feedback =
          tester.widget<Text>(find.byKey(const Key('jap_tap_feedback')));
      expect(feedback.data, 'ॐ नमः शिवाय');

      // Rises and fades out, then reports completion exactly once.
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('renders a long mantra without overflowing its box',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = await _collectErrors(tester, () async {
        for (final mantra in [
          'oṃ namaḥ śivāya oṃ namo bhagavate vāsudevāya hari krishna',
          'ॐ नमो भगवते वासुदेवाय हरे कृष्ण हरे कृष्ण हरे कृष्ण',
        ]) {
          for (final scale in [1.0, 3.5]) {
            await tester.pumpWidget(_wrap(
              state: (await _state()).$1,
              home: () => MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: GoldenTapGlow(mantra: mantra, onDone: () {}),
                    ),
                  ),
                ),
              ),
              textScaler: TextScaler.linear(scale),
            ));
            await tester.pump(const Duration(milliseconds: 60));
          }
        }
      });
      expect(errors, isEmpty);
    });

    testWidgets('never blocks a tap', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final (state, repo) = await _state();
      await tester.pumpWidget(
          _wrap(state: state, home: () => JapScreen(repository: repo)));
      await tester.pump(const Duration(milliseconds: 50));

      // Ten taps in quick succession: the effects are live for the whole burst
      // and the count must still be exactly ten.
      for (var i = 0; i < 10; i++) {
        await tester.tapAt(const Offset(120, 200));
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(find.byType(GoldenTapGlow), findsWidgets);
      await tester.pump(const Duration(milliseconds: 200));

      expect(_counter(tester), _toDev(10));
    });
  });

  group('Deity artwork', () {
    test('knows every required deity and a tint for each', () {
      for (final key in const [
        'shiva',
        'ram',
        'krishna',
        'ganesha',
        'hanuman',
        'durga',
      ]) {
        expect(DeityArtwork.tintFor(key), isNotNull);
        expect(
            DeityArtwork.assetFor(key), startsWith('assets/images/deities/'));
      }
      // An unknown key still resolves, so the screen can never crash on it.
      expect(DeityArtwork.tintFor('nobody'), isNotNull);
      expect(DeityArtwork.assetFor('nobody'), isNull);
    });

    testWidgets('renders a neutral fallback when no artwork is bundled',
        (tester) async {
      final errors = await _collectErrors(tester, () async {
        await tester.pumpWidget(_wrap(
          state: (await _state()).$1,
          home: () =>
              const DeityBackground(deityKey: 'shiva', child: SizedBox()),
        ));
        await tester.pump(const Duration(milliseconds: 30));
      });
      expect(errors, isEmpty);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('follows the selected mantra', (tester) async {
      final (state, repo) = await _state();
      await tester.pumpWidget(_wrap(
        state: state,
        home: () => JapScreen(repository: repo),
      ));
      await tester.pump(const Duration(milliseconds: 30));

      final first =
          tester.widget<DeityBackground>(find.byType(DeityBackground)).deityKey;
      state.selectedMantra = 'हरे कृष्ण हरे कृष्ण';
      await state.setRashiSign('mithun');
      await tester.pump(const Duration(milliseconds: 30));
      final second =
          tester.widget<DeityBackground>(find.byType(DeityBackground)).deityKey;
      expect(second, isNot(first));
    });
  });
}
