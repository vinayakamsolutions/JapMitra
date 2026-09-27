import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/features/jap/jap_logic.dart';

void main() {
  test('one increment adds exactly one jap', () {
    final s = const JapCounterState(count: 41, dailyGoal: 108).increment();
    expect(s.count, 42);
  });
  test('mala completion at 108', () {
    final s = const JapCounterState(count: 107, dailyGoal: 108).increment();
    expect(s.mala, 1);
    expect(s.currentJap, 0);
    expect(s.justCompletedMala, true);
  });
  test('rapid consecutive tap model keeps every tap', () {
    var s = const JapCounterState(count: 0, dailyGoal: 108);
    for (var i = 0; i < 250; i++) {
      s = s.increment();
    }
    expect(s.count, 250);
    expect(s.mala, 2);
    expect(s.currentJap, 34);
  });
  test('goal progress clamps', () {
    const s = JapCounterState(count: 1080, dailyGoal: 1008);
    expect(s.goalProgress, 1);
  });
}
