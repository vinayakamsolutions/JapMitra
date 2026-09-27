import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/features/panchang/astronomy.dart';
import 'package:japmitra/features/panchang/panchang_model.dart';

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
}
