import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/features/numerology/numerology_service.dart';

void main() {
  test('birth and life path numbers', () {
    final s = NumerologyService();
    final d = DateTime(1990, 12, 29);

    expect(s.birthNumber(d), 2);
    expect(s.lifePathNumber(d), 6);
  });

  test('today number is deterministic', () {
    final s = NumerologyService();

    expect(s.todayNumber(DateTime(2026, 9, 12)), 4);
  });

  test('future DOB is invalid', () {
    final s = NumerologyService();

    expect(
      () => s.validateDob(DateTime(2999)),
      throwsArgumentError,
    );
  });
}
