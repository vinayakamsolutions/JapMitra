/// Jap counting state machine and mantra catalog.
///
/// [JapCounterState] is immutable and pure so rapid taps can be modelled
/// without losing a single increment.
class JapCounterState {
  const JapCounterState(
      {required this.count, this.malaSize = 108, required this.dailyGoal});
  final int count;
  final int malaSize;
  final int dailyGoal;

  int get mala => count ~/ malaSize;
  int get currentJap => count % malaSize;
  double get malaProgress => currentJap / malaSize;
  double get goalProgress =>
      dailyGoal <= 0 ? 0 : (count / dailyGoal).clamp(0, 1);
  bool get justCompletedMala => count > 0 && count % malaSize == 0;
  bool get todayGoalReached => dailyGoal > 0 && count >= dailyGoal;

  JapCounterState increment() => JapCounterState(
      count: count + 1, malaSize: malaSize, dailyGoal: dailyGoal);
}

const defaultMantras = <List<String>>[
  ['Popular', 'Radhe Radhe'],
  ['Ram', 'श्री राम'],
  ['Ram', 'सीता राम'],
  ['Krishna', 'हरे कृष्ण'],
  ['Krishna', 'जय श्री कृष्ण'],
  ['Shiva', 'ॐ नमः शिवाय'],
  ['Shiva', 'महामृत्युंजय मंत्र'],
  ['Hanuman', 'ॐ हनुमते नमः'],
  ['Ram', 'जय श्री राम'],
  ['Ganesh', 'ॐ गं गणपतये नमः'],
  ['Devi', 'जय माता दी'],
  ['Devi', 'ॐ दुं दुर्गायै नमः'],
  ['Popular', 'गायत्री मंत्र'],
  ['Popular', 'ॐ शांति'],
  ['Krishna', 'गोविंद'],
  ['Shiva', 'हर हर महादेव'],
  ['Ganesh', 'श्री गणेशाय नमः'],
];

/// Canonical deity key (maps a mantra to a background watermark artwork).
String deityKeyFor(String category) {
  switch (category) {
    case 'Krishna':
      return 'krishna';
    case 'Ram':
      return 'ram';
    case 'Shiva':
      return 'shiva';
    case 'Hanuman':
      return 'hanuman';
    case 'Ganesh':
      return 'ganesha';
    case 'Devi':
      return 'durga';
    default:
      return 'om';
  }
}

/// Background art for a mantra's Jap screen.
class MantraInfo {
  const MantraInfo(
      {required this.name,
      required this.category,
      required this.deityKey,
      this.isCustom = false,
      this.displayName,
      this.photo});
  final String name;
  final String category;
  final String deityKey;
  final bool isCustom;

  /// The name the user gave a custom mantra, when they set one.
  ///
  /// [name] remains the mantra text, because that is what every count and stored
  /// record is keyed on.
  final String? displayName;

  /// Path of the deity photo the user chose for this custom mantra, or null.
  ///
  /// When set it replaces the bundled deity artwork for this mantra only.
  final String? photo;

  /// The user's name when there is one, otherwise the mantra text.
  String get label {
    final d = displayName?.trim();
    return d == null || d.isEmpty ? name : d;
  }

  /// Used to select a devotional completion greeting.
  String get deityName {
    switch (deityKey) {
      case 'krishna':
        return 'श्री कृष्ण';
      case 'ram':
        return 'श्री राम';
      case 'shiva':
        return 'शिव';
      case 'hanuman':
        return 'हनुमान जी';
      case 'ganesha':
        return 'गणेश जी';
      case 'durga':
        return 'माँ दुर्गा';
      case 'surya':
        return 'सूर्य देव';
      default:
        return 'प्रभु';
    }
  }

  String get completionMessage => 'आपकी $label की माला पूर्ण हुई। शुभ संकल्प।';
}

MantraInfo mantraInfoFor(String name,
    {bool isCustom = false, String? displayName, String? photo}) {
  for (final m in defaultMantras) {
    if (m[1] == name) {
      return MantraInfo(
          name: name, category: m[0], deityKey: deityKeyFor(m[0]));
    }
  }
  if (isCustom) {
    return MantraInfo(
        name: name,
        category: 'Custom',
        deityKey: 'om',
        isCustom: true,
        displayName: displayName,
        photo: photo);
  }
  return MantraInfo(name: name, category: 'Popular', deityKey: 'om');
}

bool isBuiltInMantra(String name) => defaultMantras.any((m) => m[1] == name);
