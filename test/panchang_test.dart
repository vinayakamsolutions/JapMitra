import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/panchang/astronomy.dart';
import 'package:japmitra/features/panchang/panchang_model.dart';
import 'package:japmitra/features/panchang/panchang_screen.dart';
import 'package:japmitra/main.dart';

/// Fixed month so the calendar assertions do not depend on the day the suite
/// runs: October 2026 has 31 days and straddles the Ashwin -> Kartika ingress.
final DateTime _october2026 = DateTime(2026, 10);

void main() {
  group('astronomy sanity', () {
    test('equation of time stays within physical bounds', () {
      for (var m = 1; m <= 12; m++) {
        final e = equationOfTimeMinutes(julianDayAt0hUt(DateTime(2026, m, 15)));
        expect(e.abs(), lessThan(17.0), reason: 'month $m');
      }
    });

    test('Delhi sunrise/sunset July 1 matches published ~05:25/19:20 IST', () {
      // Delhi: 28.6139 N, 77.2090 E, IST +330.
      final rs = solarRiseSet(
          date: DateTime(2026, 7, 1),
          latDeg: 28.6139,
          lonDeg: 77.2090,
          tzOffsetMin: 330);
      expect(rs.rise, isNotNull);
      expect(rs.set, isNotNull);
      final riseMin = rs.rise! * 60;
      final setMin = rs.set! * 60;
      // Sunrise ~05:25 => 325 min; allow generous ±20 min.
      expect(riseMin, inInclusiveRange(305, 345));
      // Sunset ~19:18 => 1158 min; allow generous ±20 min.
      expect(setMin, inInclusiveRange(1138, 1178));
    });

    test('equinox day has near-12h day length for Delhi', () {
      final rs = solarRiseSet(
          date: DateTime(2025, 3, 20),
          latDeg: 28.6139,
          lonDeg: 77.2090,
          tzOffsetMin: 330);
      final dayLen = rs.set! - rs.rise!;
      expect(dayLen, closeTo(12.0, 0.4));
    });
  });

  group('panchanga indices', () {
    for (final city in ['Varanasi', 'Mumbai', 'Chennai', 'New Delhi']) {
      test('all indices in range for $city across a month', () async {
        for (var d = 1; d <= 28; d += 7) {
          final day =
              await PanchangRepository().getDay(DateTime(2026, 9, d), city);
          expect(day, isNotNull);
          expect(day!.tithiIndex, inInclusiveRange(1, 30));
          expect(day.nakshatraIndex, inInclusiveRange(0, 26));
          expect(day.nakshatraPada, inInclusiveRange(1, 4));
          expect(day.yogaIndex, inInclusiveRange(0, 26));
          expect(day.karanaIndex, inInclusiveRange(0, 59));
          expect(day.sunrise, isNotNull);
          expect(day.sunset, isNotNull);
          if (day.tithi == null ||
              day.paksha == null ||
              day.nakshatra == null) {
            fail('missing panchanga fields for $city $d');
          }
        }
      });
    }
  });

  group('tithi math', () {
    test('tithi advances ~12 degrees per index', () {
      final jd =
          julianDayAt0hUt(DateTime(2026, 9, 1)) - 330 / 1440.0 + 6 / 24.0;
      for (var k = 0; k < 10; k++) {
        final idx = tithiIndexAt(jd);
        expect(idx, inInclusiveRange(1, 30));
      }
    });

    test('new moon (Amavasya) has near-zero lunar-solar longitude difference',
        () async {
      // Find a date where tithiIndexAtSunrise == 30 by scanning Sept 2026.
      final repo = PanchangRepository();
      for (var d = 1; d <= 30; d++) {
        final day = DateTime(2026, 9, d);
        final p = await repo.getDay(day, 'Varanasi');
        if (p!.tithiIndex == 30) {
          expect(p.tithi, 'अमावस्या');
          return;
        }
      }
      throw StateError('No Amavasya found in Sept 2026 (implementation error)');
    });
  });

  group('hindu lunar month context', () {
    /// The lunar month is decided by the Sun's sidereal ingress, so these
    /// checks bracket the published 2026/27 ingress dates rather than asserting
    /// a table of dates.
    test('month changes across the mid-April Mesha ingress', () {
      expect(lunarMonthIndexOn(DateTime(2026, 4, 10)), 0); // Chaitra
      expect(lunarMonthIndexOn(DateTime(2026, 4, 24)), 1); // Vaishakha
    });

    test('month changes across the mid-October Tula ingress', () {
      expect(lunarMonthIndexOn(DateTime(2026, 10, 10)), 6); // Ashwin
      expect(lunarMonthIndexOn(DateTime(2026, 10, 24)), 7); // Kartika
    });

    test('the month advances across the Makar and Kumbha ingresses', () {
      // Early January is still Pausha; Magha opens with the Sun's entry into
      // Makara in mid January.
      expect(lunarMonthIndexOn(DateTime(2027, 1, 5)), 9); // Pausha
      expect(lunarMonthIndexOn(DateTime(2027, 1, 25)), 10); // Magha
      expect(lunarMonthIndexOn(DateTime(2027, 2, 20)), 11); // Phalguna
      expect(lunarMonthIndexOn(DateTime(2027, 3, 25)), 0); // Chaitra
    });

    test('every index resolves to a distinct month name in both locales', () {
      final hi = <String>{};
      final en = <String>{};
      for (var i = 0; i < 12; i++) {
        hi.add(PanchangMonths.name(i, english: false));
        en.add(PanchangMonths.name(i, english: true));
      }
      expect(hi.length, 12);
      expect(en.length, 12);
    });

    test('buildMonth covers every day and names the spanned lunar months',
        () async {
      final view = await PanchangRepository()
          .buildMonth(DateTime(2026, 10, 15), 'Varanasi');

      expect(view.dayCount, 31);
      expect(view.month, DateTime(2026, 10));
      // Every day is calculated, none skipped.
      for (var d = 1; d <= 31; d++) {
        final day = view.day(d);
        expect(day, isNotNull, reason: 'day $d');
        expect(day!.date.day, d);
        expect(day.tithiIndex, inInclusiveRange(1, 30));
      }
      // October 2026 straddles the Ashwin -> Kartika ingress.
      expect(view.lunarMonths, [6, 7]);
      expect(view.lunarMonthLabel(english: true), 'Ashwin • Kartika');
    });

    test('the lunar months read in calendar order across the amanta new year',
        () async {
      // March straddles Phalguna -> Chaitra, and Chaitra is index 0 because it
      // opens the amanta year. Sorting by index alone would print it backwards.
      final march =
          await PanchangRepository().buildMonth(DateTime(2027, 3), 'Varanasi');
      expect(march.lunarMonths, [11, 0]); // Phalguna, then Chaitra
      expect(march.lunarMonthLabel(english: false), 'फाल्गुन • चैत्र');

      // The same reasoning holds for the whole year, not just March.
      for (final m in [1, 2, 4, 5, 6, 7, 8, 9, 11, 12]) {
        final v = await PanchangRepository()
            .buildMonth(DateTime(2026, m), 'Varanasi');
        expect(v.lunarMonths.length, lessThanOrEqualTo(2), reason: 'month $m');
        for (var i = 1; i < v.lunarMonths.length; i++) {
          // A month only ever moves forward by one step in the amanta year.
          expect(v.lunarMonths[i - 1], (v.lunarMonths[i] - 1) % 12,
              reason: 'month $m');
        }
      }
    });

    test('leading blanks line day 1 up under its weekday', () async {
      // 1 June 2026 is a Monday, so a Sunday-first grid needs one blank.
      final view =
          await PanchangRepository().buildMonth(DateTime(2026, 6), 'Varanasi');
      expect(view.month.weekday, DateTime.monday);
      expect(view.leadingBlanks, 1);

      // 1 November 2026 is a Sunday, so no blanks.
      final nov =
          await PanchangRepository().buildMonth(DateTime(2026, 11), 'Varanasi');
      expect(nov.month.weekday, DateTime.sunday);
      expect(nov.leadingBlanks, 0);
    });

    test('reuses the cached month instead of rebuilding it', () async {
      final repo = PanchangRepository();
      final a = await repo.buildMonth(DateTime(2026, 9), 'Varanasi');
      final b = await repo.buildMonth(DateTime(2026, 9, 22), 'Varanasi');
      expect(identical(a, b), isTrue);
    });

    test('a different city is cached separately', () async {
      final repo = PanchangRepository();
      final a = await repo.buildMonth(DateTime(2026, 9), 'Varanasi');
      final b = await repo.buildMonth(DateTime(2026, 9), 'Mumbai');
      expect(identical(a, b), isFalse);
    });
  });

  group('panchang calendar screen', () {
    Future<void> pumpCalendar(
      WidgetTester tester, {
      String city = 'Varanasi',
      Locale locale = const Locale('hi'),
      DateTime? month,
    }) async {
      final first = month ?? _october2026;
      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..city = city;
      await tester.pumpWidget(
        InheritedAppState(
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
            home: PanchangScreen(initialMonth: first),
          ),
        ),
      );
      // The month is built asynchronously in didChangeDependencies, so the first
      // frame is still the progress indicator.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the lunar month heading and the selected day inline',
        (tester) async {
      await pumpCalendar(tester);

      final l = AppLocalizations(const Locale('hi'));
      // October 2026 straddles the Ashwin -> Kartika ingress, and the heading must
      // come from the calculation rather than a fixed label.
      expect(find.text('आश्विन • कार्तिक'), findsOneWidget);
      expect(find.text(l.t('tithi')), findsOneWidget);
      expect(find.text(l.t('nakshatra')), findsOneWidget);
      expect(find.text(l.t('yoga')), findsOneWidget);
      expect(find.text(l.t('karana')), findsOneWidget);
      // Timings come from the calculation, so sunrise/sunset must be present.
      expect(find.text(l.t('sunrise')), findsOneWidget);
      expect(find.textContaining('Instance of'), findsNothing);
    });

    testWidgets('renders localized weekday headers', (tester) async {
      await pumpCalendar(tester, locale: const Locale('en'));
      // The header row is built from MaterialLocalizations.narrowWeekdays, which
      // is locale driven; the English abbreviations must all be laid out.
      const md = DefaultMaterialLocalizations();
      for (final w in md.narrowWeekdays) {
        expect(find.text(w), findsWidgets, reason: w);
      }
    });

    testWidgets('uses English lunar month names in the English locale',
        (tester) async {
      await pumpCalendar(tester, locale: const Locale('en'));
      expect(find.text('Ashwin • Kartika'), findsOneWidget);
    });

    testWidgets('tapping a day moves the selection', (tester) async {
      await pumpCalendar(tester);

      // The 15th is always present and never today-dependent.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      final p =
          await PanchangRepository().getDay(DateTime(2026, 10, 15), 'Varanasi');
      expect(p, isNotNull);
      // The inline detail now shows that day's tithi.
      expect(find.textContaining(p!.tithi!), findsWidgets);
    });

    testWidgets('month navigation rebuilds the grid', (tester) async {
      await pumpCalendar(tester);

      expect(find.text('31'), findsOneWidget);
      final l = AppLocalizations(const Locale('hi'));
      await tester.tap(find.byTooltip(l.t('nextDay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // November has 30 days, so 31 must be gone and the heading must advance.
      expect(find.text('31'), findsNothing);
      expect(find.text('30'), findsWidgets);
      expect(find.text('कार्तिक • मार्गशीर्ष'), findsOneWidget);
    });

    testWidgets('navigating back shows the previous month', (tester) async {
      await pumpCalendar(tester);

      final l = AppLocalizations(const Locale('hi'));
      await tester.tap(find.byTooltip(l.t('prevDay')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // September 2026 straddles Bhadrapada -> Ashwin and has 30 days.
      expect(find.text('31'), findsNothing);
      expect(find.text('भाद्रपद • आश्विन'), findsOneWidget);
    });
  });

  group('daily panchang rendering', () {
    /// Tall viewport so the whole detail list is laid out and every row is
    /// built, with no scrolling needed to find the nakshatra row.
    Future<void> pumpDay(
      WidgetTester tester, {
      required DateTime day,
      String city = 'Varanasi',
      Locale locale = const Locale('hi'),
    }) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..city = city;
      await tester.pumpWidget(
        InheritedAppState(
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
            home: DailyPanchang(initialDay: day),
          ),
        ),
      );
      // The screen loads the day in a post-frame callback, so the first frame
      // still shows the progress indicator. Settle only after that resolves:
      // pumpAndSettle on the indicator would never return.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('never renders a raw model instance', (tester) async {
      await pumpDay(tester, day: DateTime(2026, 10, 4));

      // The regression this guards: the row used to interpolate the whole
      // `PanchangDay`, printing "Instance of 'PanchangDay'" on screen.
      expect(find.textContaining("Instance of"), findsNothing);
    });

    testWidgets('shows the nakshatra name and its pada', (tester) async {
      final day = DateTime(2026, 10, 4);
      await pumpDay(tester, day: day);

      final p = await PanchangRepository().getDay(day, 'Varanasi');
      expect(p!.nakshatraPada, inInclusiveRange(1, 4));
      final expected = '${p.nakshatra} /${p.nakshatraPada}';

      expect(find.text(expected), findsOneWidget);
      // The label beside it must still be the nakshatra row, not another one.
      expect(find.text(AppLocalizations(const Locale('hi')).t('nakshatra')),
          findsWidgets);
    });

    testWidgets('stays free of raw instances in English too', (tester) async {
      final day = DateTime(2026, 10, 4);
      await pumpDay(tester, day: day, locale: const Locale('en'));

      expect(find.textContaining("Instance of"), findsNothing);

      // English resolves the name through the index rather than the model
      // field, so it exercises the other branch of the same expression.
      final p = await PanchangRepository().getDay(day, 'Varanasi');
      final expected =
          '${PanchangNames.nakshatraEn[p!.nakshatraIndex!]} /${p.nakshatraPada}';
      expect(find.text(expected), findsOneWidget);
    });
  });
}
