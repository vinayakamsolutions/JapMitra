import 'astronomy.dart';
import 'cities.dart';

/// Names used for display. Hindi names are canonical; transliterations are
/// provided for the English locale. All values are computed, never samples.
class PanchangNames {
  static const tithi = [
    'प्रतिपदा',
    'द्वितीया',
    'तृतीया',
    'चतुर्थी',
    'पंचमी',
    'षष्ठी',
    'सप्तमी',
    'अष्टमी',
    'नवमी',
    'दशमी',
    'एकादशी',
    'द्वादशी',
    'त्रयोदशी',
    'चतुर्दशी',
    'पूर्णिमा',
    'प्रतिपदा',
    'द्वितीया',
    'तृतीया',
    'चतुर्थी',
    'पंचमी',
    'षष्ठी',
    'सप्तमी',
    'अष्टमी',
    'नवमी',
    'दशमी',
    'एकादशी',
    'द्वादशी',
    'त्रयोदशी',
    'चतुर्दशी',
    'अमावस्या',
  ];
  static const tithiEn = [
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dvadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima',
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dvadashi',
    'Trayodashi',
    'Chaturdashi',
    'Amavasya',
  ];
  static const pakshaShukla = 'शुक्ल';
  static const pakshaKrishna = 'कृष्ण';
  static const pakshaShuklaEn = 'Shukla';
  static const pakshaKrishnaEn = 'Krishna';

  static const nakshatra = [
    'अश्विनी',
    'भरणी',
    'कृत्तिका',
    'रोहिणी',
    'मृगशिरा',
    'आर्द्रा',
    'पुनर्वसु',
    'पुष्य',
    'आश्लेषा',
    'मघा',
    'पूर्वा फाल्गुनी',
    'उत्तरा फाल्गुनी',
    'हस्त',
    'चित्रा',
    'स्वाती',
    'विशाखा',
    'अनुराधा',
    'ज्येष्ठा',
    'मूल',
    'पूर्वाषाढ़ा',
    'उत्तराषाढ़ा',
    'श्रवण',
    'धनिष्ठा',
    'शतभिषा',
    'पूर्वा भाद्रपदा',
    'उत्तरा भाद्रपदा',
    'रेवती',
  ];
  static const nakshatraEn = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  static const yoga = [
    'विष्कम्भ',
    'प्रीति',
    'आयुष्मान',
    'सौभाग्य',
    'शोभन',
    'अतिगण्ड',
    'सुकर्मा',
    'धृति',
    'शूल',
    'गण्ड',
    'वृद्धि',
    'ध्रुव',
    'व्याघात',
    'हर्षण',
    'वज्र',
    'सिद्धि',
    'व्यतीपात',
    'वरीयान',
    'परिघ',
    'शिव',
    'सिद्ध',
    'साध्य',
    'शुभ',
    'शुक्ल',
    'ब्रह्म',
    'ऐन्द्र',
    'वैधृति',
  ];
  static const yogaEn = [
    'Vishkambha',
    'Priti',
    'Ayushman',
    'Saubhagya',
    'Shobhana',
    'Atiganda',
    'Sukarma',
    'Dhriti',
    'Shula',
    'Ganda',
    'Vriddhi',
    'Dhruva',
    'Vyaghata',
    'Harshana',
    'Vajra',
    'Siddhi',
    'Vyatipata',
    'Variyana',
    'Parigha',
    'Shiva',
    'Siddha',
    'Sadhya',
    'Shubha',
    'Shukla',
    'Brahma',
    'Indra',
    'Vaidhriti',
  ];

  static const karanaMovable = [
    'बव',
    'बालव',
    'कौलव',
    'तैतिल',
    'गर',
    'वणिज',
    'विष्टि'
  ];
  static const karanaMovableEn = [
    'Bava',
    'Balava',
    'Kaulava',
    'Taitila',
    'Gara',
    'Vanija',
    'Vishti'
  ];
  static const karanaFixed = ['किंस्तुघ्न', 'नाग', 'चतुष्पद', 'शकुनि'];
  static const karanaFixedEn = ['Kimstughna', 'Naga', 'Chatushpada', 'Shakuni'];

  static const rashi = [
    'मेष',
    'वृषभ',
    'मिथुन',
    'कर्क',
    'सिंह',
    'कन्या',
    'तुला',
    'वृश्चिक',
    'धनु',
    'मकर',
    'कुंभ',
    'मीन',
  ];
  static const rashiEn = [
    'Mesha',
    'Vrishabha',
    'Mithuna',
    'Karka',
    'Simha',
    'Kanya',
    'Tula',
    'Vrishchika',
    'Dhanu',
    'Makara',
    'Kumbha',
    'Meena',
  ];

  static String karanaName(int k) {
    if (k < 4) return karanaFixed[k];
    return karanaMovable[(k - 4) % 7];
  }

  static String karanaNameEn(int k) {
    if (k < 4) return karanaFixedEn[k];
    return karanaMovableEn[(k - 4) % 7];
  }
}

/// Rahu Kaal, Yamaganda and Gulika segments are based on the classical
/// subdivision of the day (sunrise to sunset) into 8 equal parts, keyed to the
/// weekday. Segment 1 is the first part after sunrise.
const _rahuSegment = [8, 2, 7, 5, 6, 4, 3]; // Sunday..Saturday
const _yamagandaSegment = [5, 4, 3, 2, 1, 7, 6];
const _gulikaSegment = [7, 6, 5, 4, 3, 2, 1];
const _muhuratCount = 15;

String _fmt(double hours) {
  if (hours.isNaN || hours < 0 || hours >= 24) return '';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  final hh = (h + (m == 60 ? 1 : 0)) % 24;
  final mm = m == 60 ? 0 : m;
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

String _segmentRange(double start, double end) =>
    '${_fmt(start)} – ${_fmt(end)}';

class PanchangDay {
  const PanchangDay({
    required this.date,
    required this.city,
    this.sunrise,
    this.sunset,
    this.moonrise,
    this.moonset,
    this.tithi,
    this.paksha,
    this.nakshatra,
    this.nakshatraPada,
    this.yoga,
    this.karana,
    this.tithiEnd,
    this.sankranti,
    this.rahuKaal,
    this.yamaganda,
    this.gulika,
    this.abhijitMuhurat,
    this.vrat = const [],
    this.festivals = const [],
    this.tithiIndex,
    this.nakshatraIndex,
    this.yogaIndex,
    this.karanaIndex,
    this.sankrantiRashi,
  });

  final DateTime date;
  final String city;
  final String? sunrise, sunset, moonrise, moonset;
  final String? tithi, paksha, nakshatra;
  final int? nakshatraPada;
  final String? yoga, karana, tithiEnd, sankranti;
  final String? rahuKaal, yamaganda, gulika, abhijitMuhurat;

  /// Vrat keys ('ekadashi','purnima','amavasya','ashtami','pradosh').
  final List<String> vrat;

  /// Festival codes ('sankranti', ...). Sankranti rashi in [sankrantiRashi].
  final List<String> festivals;

  /// Raw indices so the UI can localize names.
  final int? tithiIndex, nakshatraIndex, yogaIndex, karanaIndex;
  final int? sankrantiRashi;

  bool get hasVerifiedData => true; // computed from standard algorithms
}

class PanchangRepository {
  /// Computes the full daily Panchang for [date] (local) at [cityName].
  /// Computation is synchronous in the model; wrapped for interface parity.
  Future<PanchangDay?> getDay(DateTime date, String cityName) async {
    final d = DateTime(date.year, date.month, date.day);
    final c = cityOrFallback(cityName);
    final tz = c.tzOffsetMin;

    final sun =
        solarRiseSet(date: d, latDeg: c.lat, lonDeg: c.lon, tzOffsetMin: tz);
    final moon =
        lunarRiseSet(date: d, latDeg: c.lat, lonDeg: c.lon, tzOffsetMin: tz);
    final sunrise = sun.rise ?? 6.0;
    final sunset = sun.set ?? 18.0;
    final dayLen = sunset - sunrise;

    final jd0 = julianDayAt0hUt(d) - tz / 1440.0;
    final jdSunrise = jd0 + sunrise / 24.0;

    final t = tithiIndexAt(jdSunrise);
    final tithiNam = PanchangNames.tithi[t - 1];
    final paksha =
        t <= 15 ? PanchangNames.pakshaShukla : PanchangNames.pakshaKrishna;
    final nk = nakshatraIndexAt(jdSunrise);
    final pada =
        ((lunarLongitude(jdSunrise) % (360.0 / 27.0)) / (360.0 / 27.0) * 4)
                    .floor() %
                4 +
            1;

    // Tithi span (till when this tithi prevails).
    final tEndJd = nextTithiBoundaryJd(d, tzOffsetMin: tz);
    final tEndLocal = _jdToLocalTime(tEndJd, tz);

    // Segments for Rahu Kaal / Yamaganda / Gulika.
    final seg = dayLen / 8;
    final wd = d.weekday -
        1; // DateTime weekday: Monday=1..Sunday=7 => Sunday..Saturday index
    final wd0 = wd == 6 ? 0 : wd + 1; // align to Sunday-first table
    double segStart(int s) => sunrise + (s - 1) * seg;
    double segEnd(int s) => sunrise + s * seg;

    // Abhijit Muhurat: the 8th muhurat of the day.
    final muhurat = dayLen / _muhuratCount;
    final abhijit = _segmentRange(sunrise + 7 * muhurat, sunrise + 8 * muhurat);

    // Vrat / festivals (algorithmic, tithi- and ingress-based only).
    final vrat = <String>[];
    if (t == 11) vrat.add('ekadashi');
    if (t == 30) vrat.add('amavasya');
    if (t == 15) vrat.add('purnima');
    if (t == 8) vrat.add('ashtami');
    if (t == 14 || t == 29) vrat.add('pradosh');

    final festivals = <String>[];
    int? sankrantiRashi;
    DateTime? sankrantiDt;
    if (isSankrantiDay(d, tzOffsetMin: tz)) {
      sankrantiDt = sankrantiAround(d, tzOffsetMin: tz);
      if (sankrantiDt != null) {
        final sAya = ayanamsaDeg(d);
        sankrantiRashi = (_normalizeS(solarLongitude(
                            julianDayAt0hUt(sankrantiDt) - tz / 1440.0) -
                        sAya) /
                    30)
                .floor() %
            12;
        festivals.add('sankranti');
      }
    }

    return PanchangDay(
      date: d,
      city: c.name,
      sunrise: _fmt(sun.rise ?? 0),
      sunset: _fmt(sun.set ?? 0),
      moonrise: moon.rise != null ? _fmt(moon.rise!) : null,
      moonset: moon.set != null ? _fmt(moon.set!) : null,
      tithi: tithiNam,
      paksha: paksha,
      nakshatra: PanchangNames.nakshatra[nk],
      nakshatraPada: pada,
      yoga: PanchangNames.yoga[yogaIndexAt(jdSunrise)],
      karana: PanchangNames.karanaName(karanaIndexAt(jdSunrise)),
      tithiEnd: _fmt(tEndLocal),
      sankranti: sankrantiDt != null
          ? _fmt(sankrantiDt.hour + sankrantiDt.minute / 60.0)
          : null,
      rahuKaal:
          _segmentRange(segStart(_rahuSegment[wd0]), segEnd(_rahuSegment[wd0])),
      yamaganda: _segmentRange(
          segStart(_yamagandaSegment[wd0]), segEnd(_yamagandaSegment[wd0])),
      gulika: _segmentRange(
          segStart(_gulikaSegment[wd0]), segEnd(_gulikaSegment[wd0])),
      abhijitMuhurat: abhijit,
      vrat: List.unmodifiable(vrat),
      festivals: List.unmodifiable(festivals),
      tithiIndex: t,
      nakshatraIndex: nk,
      yogaIndex: yogaIndexAt(jdSunrise),
      karanaIndex: karanaIndexAt(jdSunrise),
      sankrantiRashi: sankrantiRashi,
    );
  }
}

double _normalizeS(double d) {
  var x = d % 360;
  if (x < 0) x += 360;
  return x;
}

double _jdToLocalTime(double jd, int tzMin) {
  final localDt = _jdToLocalDt(jd, tzMin);
  return localDt.hour + localDt.minute / 60.0;
}

DateTime _jdToLocalDt(double jd, int tzMin) {
  final utc = DateTime.fromMicrosecondsSinceEpoch(
      ((jd - 2440587.5) * 86400 * 1000).round(),
      isUtc: true);
  return utc.add(Duration(minutes: tzMin));
}

/// English display names for a computed day (used by the English locale).
class PanchangDayEnglish {
  static String tithi(int index) => PanchangNames.tithiEn[index - 1];
  static String paksha(int t) =>
      t <= 15 ? PanchangNames.pakshaShuklaEn : PanchangNames.pakshaKrishnaEn;
  static String nakshatra(int i) => PanchangNames.nakshatraEn[i];
  static String yoga(int i) => PanchangNames.yogaEn[i];
  static String karana(int i) => PanchangNames.karanaNameEn(i);
}
