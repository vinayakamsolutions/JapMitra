/// The result of a numerology calculation for one date of birth.
///
/// Every number here is computed by [NumerologyService] from the entered date;
/// nothing is prefilled or cached.
class NumerologyInsight {
  const NumerologyInsight({
    required this.birthNumber,
    required this.lifePathNumber,
    required this.todayNumber,
    required this.luckyNumber,
    required this.luckyColour,
    required this.dailyGuidance,
  });

  /// The number derived from the day of birth alone.
  final int birthNumber;

  /// The number derived from the full date of birth.
  final int lifePathNumber;

  /// The number for the date the reading was requested for.
  final int todayNumber;

  /// Derived from the birth number and the day's number.
  final int luckyNumber;

  /// Traditional colour association for [luckyNumber].
  final String luckyColour;

  /// Traditional association text for [luckyNumber].
  ///
  /// This is a fixed description of numerological tradition, not a prediction
  /// about the person's future, and the UI says so.
  final String dailyGuidance;
}

/// Numerology calculations and their traditional associations.
class NumerologyService {
  /// Traditional colour association per number, 1-9.
  static const Map<int, String> _colours = <int, String>{
    1: 'Ruby red',
    2: 'Pearl white',
    3: 'Emerald green',
    4: 'Diamond white',
    5: 'Sky blue',
    6: 'Opal cream',
    7: 'Deep blue',
    8: 'Onyx black',
    9: 'Maroon gold',
  };

  /// Traditional association text per number, 1-9.
  static const Map<int, String> _guidance = <int, String>{
    1: 'Traditionally linked with new beginnings and self-leadership.',
    2: 'Traditionally linked with cooperation, balance and partnerships.',
    3: 'Traditionally linked with expression, creativity and joy.',
    4: 'Traditionally linked with hard work, structure and reliability.',
    5: 'Traditionally linked with freedom, change and versatility.',
    6: 'Traditionally linked with family, care and responsibility.',
    7: 'Traditionally linked with enquiry, analysis and solitude.',
    8: 'Traditionally linked with ambition, authority and material focus.',
    9: 'Traditionally linked with compassion, service and completion.',
  };

  /// Repeatedly adds the digits of [n] until a single digit remains.
  int digitSum(int n) {
    if (n < 0) throw ArgumentError('number must be positive');
    while (n > 9) {
      n = n.toString().split('').map(int.parse).reduce((a, b) => a + b);
    }
    return n;
  }

  /// Rejects a date of birth that is in the future or before the supported
  /// range, so a calculation can never silently use an impossible date.
  void validateDob(DateTime dob, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (dob.isAfter(current)) {
      throw ArgumentError('Date of birth cannot be in the future');
    }
    if (dob.year < 1900) {
      throw ArgumentError('Date of birth is out of supported range');
    }
  }

  /// Birth Number: reduced day of birth.
  int birthNumber(DateTime dob) {
    validateDob(dob);
    return digitSum(dob.day);
  }

  /// Life Path Number: reduced full date of birth.
  int lifePathNumber(DateTime dob) {
    validateDob(dob);
    return digitSum('${dob.day}${dob.month}${dob.year}'
        .split('')
        .map(int.parse)
        .reduce((a, b) => a + b));
  }

  /// The day's number, reduced from the real calendar date.
  int todayNumber([DateTime? day]) {
    final d = day ?? DateTime.now();
    return digitSum(d.day + d.month + d.year);
  }

  /// Full reading for [dob] on [day].
  ///
  /// All three numbers are derived from the arguments; the colour and guidance
  /// are the traditional associations of the resulting lucky number, so the same
  /// date always produces the same result.
  NumerologyInsight insight(DateTime dob, {DateTime? day}) {
    validateDob(dob);
    final birth = birthNumber(dob);
    final path = lifePathNumber(dob);
    final today = todayNumber(day);
    final lucky = digitSum(birth + today);
    return NumerologyInsight(
      birthNumber: birth,
      lifePathNumber: path,
      todayNumber: today,
      luckyNumber: lucky,
      luckyColour: _colours[lucky]!,
      dailyGuidance: _guidance[lucky]!,
    );
  }
}
