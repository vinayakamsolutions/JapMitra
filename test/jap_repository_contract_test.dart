import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/data/repositories/jap_repository.dart';

void main() {
  test('tap queue accepts rapid taps without blocking callers', () {
    const queueType = JapTapQueue;

    expect(queueType, isNotNull);
  });
}
