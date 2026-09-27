/// Offline astronomical engine for the Panchang, built on standard published
/// algorithms (Meeus, "Astronomical Algorithms"; NOAA solar position method).
///
/// Accuracy notes (documented limits, not fake UI data):
///  - Solar longitude uses the standard series (accurate ~0.01 deg for
///    1900–2100).
///  - Lunar longitude uses the 60-term periodic model (~0.01 deg); lunar
///    latitude uses the 24 main terms (~0.1 deg).
///  - Sun rise/set ~1–2 minutes; moonrise/moonset a few minutes.
///  - Tithi/nakshatra/yoga/karana are derived from longitudes and are robust
///    to these tolerances except within a few minutes of a boundary.
///  - Lahiri ayanamsa is modelled linearly for the current era.
/// None of these values are hard-coded samples; every value is computed from
/// the selected date and observer location/timezone.
library;

// Variable names in this file follow Meeus' published notation (L0, M, M', F, T)
// and are intentionally not lowerCamelCase.
// ignore_for_file: non_constant_identifier_names

import 'dart:math' as math;

const _dtr = math.pi / 180.0;

double _rad(double deg) => deg * _dtr;
double _deg(double rad) => rad / _dtr;

/// Normalize an angle in degrees to [0,360).
double _normalize360(double deg) {
  var d = deg % 360.0;
  if (d < 0) d += 360.0;
  return d;
}

/// Normalize degrees to (-180,180].
double _normalize180(double deg) {
  var d = _normalize360(deg);
  if (d > 180) d -= 360.0;
  return d;
}

/// Julian day for the Gregorian date at 00:00 UT (Meeus Ch. 7).
double julianDayAt0hUt(DateTime date) {
  final y = date.year;
  final m = date.month;
  final d = date.day;
  final a = ((14 - m) / 12).floor();
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  final jdn = d +
      ((153 * mm + 2) / 5).floor() +
      365 * yy +
      (yy / 4).floor() -
      (yy / 100).floor() +
      (yy / 400).floor() -
      32045;
  return jdn - 0.5; // JD at 0h UT
}

double _century(double jd) => (jd - 2451545.0) / 36525.0;

/// Geocentric apparent solar longitude (degrees), equinox of date.
double solarLongitude(double jd) {
  final T = _century(jd);
  final L0 = _normalize360(280.46646 + T * (36000.76983 + T * 0.0003032));
  final M = _normalize360(357.52911 + T * (35999.05029 - 0.0001537 * T));
  final C = (1.914602 - T * (0.004817 + 0.000014 * T)) * math.sin(_rad(M)) +
      (0.019993 - 0.000101 * T) * math.sin(_rad(2 * M)) +
      0.000289 * math.sin(_rad(3 * M));
  final omega = 125.04 - 1934.136 * T;
  final trueLong = L0 + C;
  return _normalize360(trueLong - 0.00569 - 0.00478 * math.sin(_rad(omega)));
}

/// Mean obliquity of the ecliptic (degrees).
double meanObliquity(double jd) {
  final T = _century(jd);
  return 23.439291111 - T * (0.013004167 - T * (1.6389e-7 - T * 5.0361e-7));
}

/// Nutation in longitude (degrees), dominant terms.
double _nutationLongitude(double jd) {
  final T = _century(jd);
  final omega = _normalize360(125.04452 - 1934.136261 * T);
  final L0 = _normalize360(280.46646 + T * (36000.76983 + T * 0.0003032));
  return ((-17.20 * math.sin(_rad(omega)) - 1.32 * math.sin(_rad(2 * L0))) /
      3600.0);
}

double _powE(double e, int k) => math.pow(e, k.abs()).toDouble();

/// Apparent geocentric lunar longitude (degrees).
double lunarLongitude(double jd) {
  final T = _century(jd);
  final D = _normalize360(
      297.8501921 + T * (445267.1114034 - T * (0.0018819 - T / 545868.0)));
  final M = _normalize360(
      357.5291092 + T * (35999.0502909 - T * (0.0001536 + T / 24490000.0)));
  final Mp = _normalize360(
      134.9633964 + T * (477198.8675055 + T * (0.0087414 + T / 69699.0)));
  final F = _normalize360(
      93.2720950 + T * (483202.0175233 - T * (0.0036539 - T / 3526000.0)));
  final E = 1.0 - 0.002516 * T - 0.0000074 * T * T;
  var l = 0.0;
  for (final row in _lunarLongitudeTerms) {
    final arg = row.d * D + row.m * M + row.mp * Mp + row.f * F;
    l += row.l * _powE(E, row.m) * math.sin(_rad(arg));
  }
  l += 3958.0 * math.sin(_rad(119.75 + 131.849 * T));
  l += 318.0 * math.sin(_rad(53.09 + 479264.290 * T));
  l += 1962.0 * math.sin(_rad(313.45 + 481266.484 * T));
  // Mean longitude (accumulated motion of the Moon), Meeus Ch. 47.
  final l0 = 218.3164477 +
      481267.88123421 * T -
      0.0015786 * T * T +
      T * T * T / 538841.0 -
      T * T * T * T / 65194000.0;
  return _normalize360(l0 + l / 1e6 + _nutationLongitude(jd));
}

/// Apparent geocentric lunar latitude (degrees).
double lunarLatitude(double jd) {
  final T = _century(jd);
  final D = _normalize360(
      297.8501921 + T * (445267.1114034 - T * (0.0018819 - T / 545868.0)));
  final M = _normalize360(
      357.5291092 + T * (35999.0502909 - T * (0.0001536 + T / 24490000.0)));
  final Mp = _normalize360(
      134.9633964 + T * (477198.8675055 + T * (0.0087414 + T / 69699.0)));
  final F = _normalize360(
      93.2720950 + T * (483202.0175233 - T * (0.0036539 - T / 3526000.0)));
  final E = 1.0 - 0.002516 * T - 0.0000074 * T * T;
  var b = 0.0;
  for (final row in _lunarLatitudeTerms) {
    final arg = row.d * D + row.m * M + row.mp * Mp + row.f * F;
    b += row.b * _powE(E, row.m) * math.sin(_rad(arg));
  }
  return _normalize180(b / 1e6);
}

/// Solar equatorial coordinates (right ascension, declination) in degrees.
(double ra, double dec) solarEquatorial(double jd) {
  final lon = _rad(solarLongitude(jd));
  final eps = _rad(meanObliquity(jd));
  final ra = _normalize360(
      _deg(math.atan2(math.cos(eps) * math.sin(lon), math.cos(lon))));
  final dec = _deg(math.asin(math.sin(eps) * math.sin(lon)));
  return (ra, dec);
}

/// Lunar equatorial coordinates (right ascension, declination) in degrees.
(double ra, double dec) lunarEquatorial(double jd) {
  final lon = _rad(lunarLongitude(jd));
  final lat = _rad(lunarLatitude(jd));
  final eps = _rad(meanObliquity(jd));
  final ra = _normalize360(_deg(math.atan2(
      math.sin(lon) * math.cos(eps) - math.tan(lat) * math.sin(eps),
      math.cos(lon))));
  final dec = _deg(math.asin(math.sin(lat) * math.cos(eps) +
      math.cos(lat) * math.sin(eps) * math.sin(lon)));
  return (ra, dec);
}

/// Apparent altitude (degrees) of a body with equatorial (ra, dec) at [jd].
double _altitude(
    double jd, double latDeg, double lonDeg, double raDeg, double decDeg) {
  final H = _normalize360(_greenwichSiderealDeg(jd) + lonDeg - raDeg);
  final lat = _rad(latDeg);
  final dec = _rad(decDeg);
  return _deg(math.asin(math.sin(lat) * math.sin(dec) +
      math.cos(lat) * math.cos(dec) * math.cos(_rad(H))));
}

double _greenwichSiderealDeg(double jd) {
  final Tu = (jd - 2451545.0) / 36525.0;
  final g = 280.46061837 +
      360.98564736629 * (jd - 2451545.0) +
      0.000387933 * Tu * Tu -
      Tu * Tu * Tu / 38710000.0;
  return _normalize360(g);
}

/// Equation of time in minutes (NOAA method). Negative => solar time ahead.
double equationOfTimeMinutes(double jd) {
  final T = _century(jd);
  final L0 = _normalize360(280.46646 + T * (36000.76983 + T * 0.0003032));
  final M = _normalize360(357.52911 + T * (35999.05029 - 0.0001537 * T));
  final C = (1.914602 - T * (0.004817 + 0.000014 * T)) * math.sin(_rad(M)) +
      (0.019993 - 0.000101 * T) * math.sin(_rad(2 * M)) +
      0.000289 * math.sin(_rad(3 * M));
  final omega = 125.04 - 1934.136 * T;
  final lambda =
      _normalize360(L0 + C - 0.00569 - 0.00478 * math.sin(_rad(omega)));
  final eps = meanObliquity(jd) + 0.00256 * math.cos(_rad(omega));
  final ra = _normalize360(_deg(math.atan2(
      math.cos(_rad(eps)) * math.sin(_rad(lambda)), math.cos(_rad(lambda)))));
  return 4.0 *
      _normalize180(
          L0 - 0.0057183 - ra + _nutationLongitude(jd) * math.cos(_rad(eps)));
}

class RiseSetAt {
  const RiseSetAt({this.rise, this.set});
  final double? rise; // local hours
  final double? set; // local hours
  bool get hasAny => rise != null || set != null;
}

/// Sunrise/sunset (local hours) for the given observer and day.
/// h0 = -0.833 deg (standard: limb + refraction).
RiseSetAt solarRiseSet({
  required DateTime date,
  required double latDeg,
  required double lonDeg,
  required int tzOffsetMin,
  double h0 = -0.833,
}) {
  final jd0 = julianDayAt0hUt(date) - tzOffsetMin / 1440.0;
  final crossings = _crossings(jd0, latDeg, lonDeg, h0, solarEquatorial);
  return _riseSetOf(crossings);
}

/// Moonrise/moonset (local hours). h0 = +0.125 deg (mean parallax+limb+refraction).
RiseSetAt lunarRiseSet({
  required DateTime date,
  required double latDeg,
  required double lonDeg,
  required int tzOffsetMin,
}) {
  final jd0 = julianDayAt0hUt(date) - tzOffsetMin / 1440.0;
  final crossings = _crossings(jd0, latDeg, lonDeg, 0.125, lunarEquatorial);
  return _riseSetOf(crossings);
}

List<double> _crossings(
  double jd0,
  double latDeg,
  double lonDeg,
  double h0,
  (double, double) Function(double) equatorialAt,
) {
  var prev = _above(jd0, latDeg, lonDeg, equatorialAt, h0);
  final crossings = <double>[];
  for (var m = 1; m <= 1440; m++) {
    final next = _above(jd0 + m / 1440.0, latDeg, lonDeg, equatorialAt, h0);
    if ((prev < 0 && next >= 0) || (prev > 0 && next <= 0)) {
      final f = prev / (prev - next); // interpolate root
      crossings.add(m - 1 + f);
    }
    prev = next;
  }
  return crossings;
}

double _above(double jd, double latDeg, double lonDeg,
    (double, double) Function(double) eq, double h0) {
  final (ra, dec) = eq(jd);
  return _altitude(jd, latDeg, lonDeg, ra, dec) - h0;
}

RiseSetAt _riseSetOf(List<double> crossings) {
  if (crossings.isEmpty) return const RiseSetAt();
  final sorted = [...crossings]..sort();
  return RiseSetAt(
      rise: sorted.first / 60.0,
      set: sorted.length > 1 ? sorted.last / 60.0 : null);
}

/// Tithi index 1..30 at epoch (1 = Shukla Pratipada ... 30 = Amavasya).
int tithiIndexAt(double jd) {
  final diff = _normalize360(lunarLongitude(jd) - solarLongitude(jd));
  return (diff / 12.0).floor() % 30 + 1;
}

/// Nakshatra index 0..26.
int nakshatraIndexAt(double jd) {
  final l = _normalize360(lunarLongitude(jd));
  return (l / (360.0 / 27.0)).floor() % 27;
}

/// Yoga index 0..26.
int yogaIndexAt(double jd) {
  final l = _normalize360(solarLongitude(jd) + lunarLongitude(jd));
  return (l / (360.0 / 27.0)).floor() % 27;
}

/// Karana index 0..59 (full cycle; see panchang_model for name mapping).
int karanaIndexAt(double jd) {
  final diff = _normalize360(lunarLongitude(jd) - solarLongitude(jd));
  return (diff / 6.0).floor() % 60;
}

/// Lahiri sidereal ayanamsa for the current era (linear model).
double ayanamsaDeg(DateTime date) {
  final year = date.year + (date.month - 1) / 12.0 + (date.day - 1) / 365.25;
  return 23.8564 + (year - 2000) * 0.013974;
}

/// The next/any Sankranti within +/- 2 days of [date], or null.
DateTime? sankrantiAround(DateTime date, {int tzOffsetMin = 330}) {
  final centre = DateTime(date.year, date.month, date.day, 12);
  final jd0 = julianDayAt0hUt(centre) - tzOffsetMin / 1440.0;
  final aya = ayanamsaDeg(date);
  var prevIdx = _siderealSector(jd0 - 2.0, aya);
  for (var minute = 1; minute <= 4 * 1440; minute++) {
    final jd = jd0 - 2.0 + minute / 1440.0;
    final idx = _siderealSector(jd, aya);
    if (idx != prevIdx) return _jdToDateTime(jd - 1 / 1440.0, tzOffsetMin);
    prevIdx = idx;
  }
  return null;
}

bool isSankrantiDay(DateTime date, {int tzOffsetMin = 330}) {
  final s = sankrantiAround(date, tzOffsetMin: tzOffsetMin);
  if (s == null) return false;
  return s.year == date.year && s.month == date.month && s.day == date.day;
}

int _siderealSector(double jd, double aya) {
  return (_normalize360(solarLongitude(jd) - aya) / 30).floor() % 12;
}

/// Convert a full Julian date (with fraction) to a local DateTime.
DateTime _jdToDateTime(double jd, int tzOffsetMin) {
  final z0 = (jd + 0.5).floor();
  final f = jd + 0.5 - z0;
  var z = z0;
  if (z >= 2299161) {
    final alpha = ((z - 1867216.25) / 36524.25).floor();
    z += 1 + alpha - (alpha / 4).floor();
  }
  final b = z + 1524;
  final c = ((b - 122.1) / 365.25).floor();
  final d = (365.25 * c).floor();
  final e = ((b - d) / 30.6001).floor();
  final day = b - d - (30.6001 * e).floor();
  final month = e < 14 ? e - 1 : e - 13;
  final year = month > 2 ? c - 4716 : c - 4715;
  final offsetMin = (f * 1440.0).round() + tzOffsetMin;
  return DateTime(year, month, day).add(Duration(minutes: offsetMin));
}

/// The tithi index prevailing at sunrise on [date] for the given city.
int tithiIndexAtSunrise({
  required DateTime date,
  required double latDeg,
  required double lonDeg,
  required int tzOffsetMin,
}) {
  final rise = solarRiseSet(
          date: date, latDeg: latDeg, lonDeg: lonDeg, tzOffsetMin: tzOffsetMin)
      .rise;
  final jd0 = julianDayAt0hUt(date) - tzOffsetMin / 1440.0;
  return tithiIndexAt(jd0 + (rise ?? 6.0) / 24.0);
}

/// The next epoch (JD) at/after the given local day's start+6h when the tithi changes.
double nextTithiBoundaryJd(DateTime date, {int tzOffsetMin = 330}) {
  final jd0 = julianDayAt0hUt(date) - tzOffsetMin / 1440.0;
  final t0 = tithiIndexAt(jd0 + 6.0 / 24.0);
  for (var h = 6; h < 54; h++) {
    if (tithiIndexAt(jd0 + h / 24.0) != t0) return jd0 + h / 24.0;
  }
  return jd0 + 1.25;
}

// ---- Lunar periodic term tables (Meeus Table 47.A / 47.B) ----

class _Term3 {
  const _Term3(this.d, this.m, this.mp, this.f);
  final int d;
  final int m;
  final int mp;
  final int f;
}

class _LonTerm extends _Term3 {
  const _LonTerm(super.d, super.m, super.mp, super.f, this.l);
  final double l;
}

class _LatTerm extends _Term3 {
  const _LatTerm(super.d, super.m, super.mp, super.f, this.b);
  final double b;
}

const _lunarLongitudeTerms = <_LonTerm>[
  _LonTerm(0, 0, 1, 0, 6288774),
  _LonTerm(2, 0, -1, 0, 1274027),
  _LonTerm(2, 0, 0, 0, 658314),
  _LonTerm(0, 0, 2, 0, 213618),
  _LonTerm(0, 1, 0, 0, -185116),
  _LonTerm(0, 0, 0, 2, -114332),
  _LonTerm(2, 0, -2, 0, 58793),
  _LonTerm(2, -1, -1, 0, 57066),
  _LonTerm(2, 0, 1, 0, 53322),
  _LonTerm(2, -1, 0, 0, 45758),
  _LonTerm(0, 1, -1, 0, -40923),
  _LonTerm(1, 0, 0, 0, -34720),
  _LonTerm(0, 1, 1, 0, -30383),
  _LonTerm(2, 0, 0, -2, 15327),
  _LonTerm(0, 0, 1, 2, -12528),
  _LonTerm(0, 0, 1, -2, 10980),
  _LonTerm(4, 0, -1, 0, 10675),
  _LonTerm(0, 0, 3, 0, 10034),
  _LonTerm(4, 0, -2, 0, 8548),
  _LonTerm(2, 1, -1, 0, -7888),
  _LonTerm(2, 1, 0, 0, -6766),
  _LonTerm(1, 0, -1, 0, -5163),
  _LonTerm(1, 1, 0, 0, 4987),
  _LonTerm(2, -1, 1, 0, 4036),
  _LonTerm(2, 0, 2, 0, 3994),
  _LonTerm(4, 0, 0, 0, 3861),
  _LonTerm(2, 0, -3, 0, 3665),
  _LonTerm(0, 1, -2, 0, -2689),
  _LonTerm(2, 0, -1, 2, -2602),
  _LonTerm(2, -1, -2, 0, 2390),
  _LonTerm(1, 0, 1, 0, -2348),
  _LonTerm(2, -2, 0, 0, 2236),
  _LonTerm(0, 1, 2, 0, -2120),
  _LonTerm(0, 2, 0, 0, -2069),
  _LonTerm(2, -2, -1, 0, 2048),
  _LonTerm(2, 0, 1, -2, -1773),
  _LonTerm(2, 0, 0, 2, -1595),
  _LonTerm(4, -1, -1, 0, 1215),
  _LonTerm(0, 0, 2, 2, -1110),
  _LonTerm(3, 0, -1, 0, -892),
  _LonTerm(2, 1, 1, 0, -810),
  _LonTerm(4, -1, -2, 0, 759),
  _LonTerm(0, 2, -1, 0, -713),
  _LonTerm(2, 2, -1, 0, -700),
  _LonTerm(2, 1, -2, 0, 691),
  _LonTerm(2, -1, 0, -2, 596),
  _LonTerm(4, 0, 1, 0, 549),
  _LonTerm(0, 0, 4, 0, 537),
  _LonTerm(4, -1, 0, 0, 520),
  _LonTerm(1, 0, -2, 0, -487),
  _LonTerm(2, 1, 0, -2, -399),
  _LonTerm(0, 0, 2, -2, -381),
  _LonTerm(1, 1, 1, 0, 351),
  _LonTerm(3, 0, -2, 0, -340),
  _LonTerm(4, 0, -3, 0, 330),
  _LonTerm(2, -1, 2, 0, 327),
  _LonTerm(0, 2, 1, 0, -323),
  _LonTerm(1, 1, -1, 0, 299),
  _LonTerm(2, 0, 3, 0, 294),
  _LonTerm(2, 0, -1, -2, 0),
];

const _lunarLatitudeTerms = <_LatTerm>[
  _LatTerm(0, 0, 0, 1, 5128122),
  _LatTerm(0, 0, 1, 1, 280602),
  _LatTerm(0, 0, 1, -1, 277693),
  _LatTerm(2, 0, 0, -1, 173237),
  _LatTerm(2, 0, -1, 1, 55413),
  _LatTerm(2, 0, -1, -1, 46271),
  _LatTerm(2, 0, 0, 1, 32573),
  _LatTerm(0, 0, 2, 1, 17198),
  _LatTerm(2, 0, 1, -1, 9266),
  _LatTerm(0, 0, 2, -1, 8822),
  _LatTerm(2, -1, 0, -1, 8216),
  _LatTerm(2, 0, -2, -1, 4324),
  _LatTerm(2, 0, 1, 1, 4200),
  _LatTerm(2, 1, 0, -1, -3359),
  _LatTerm(2, -1, -1, 1, 2463),
  _LatTerm(2, -1, 0, 1, 2211),
  _LatTerm(2, -1, -1, -1, 2065),
  _LatTerm(0, 1, -1, -1, -1870),
  _LatTerm(4, 0, -1, -1, 1828),
  _LatTerm(0, 1, 0, 1, -1794),
  _LatTerm(0, 0, 0, 3, -1749),
  _LatTerm(0, 1, -1, 1, -1565),
  _LatTerm(1, 0, 0, 1, -1491),
  _LatTerm(0, 1, 1, 1, -1475),
];
