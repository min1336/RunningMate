import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/features/running/running_metrics.dart';

void main() {
  group('RunningMetrics.formatPace', () {
    test('returns placeholder when distance is zero', () {
      expect(
        RunningMetrics.formatPace(elapsedSeconds: 300, distanceMeters: 0),
        '--:--',
      );
    });

    test('formats average pace as minutes and seconds per kilometer', () {
      expect(
        RunningMetrics.formatPace(elapsedSeconds: 300, distanceMeters: 1000),
        '05:00',
      );
    });
  });

  group('RunningMetrics.formatElapsedTime', () {
    test('formats elapsed seconds as mm:ss', () {
      expect(RunningMetrics.formatElapsedTime(125), '02:05');
    });
  });

  group('RunningMetrics.calculateCalories', () {
    test('preserves the existing flat-running calorie formula', () {
      expect(
        RunningMetrics.calculateCalories(
          speed: 8,
          gradient: 0,
          elapsedSeconds: 1800,
        ),
        350,
      );
    });

    test('adds uphill intensity to the existing calorie formula', () {
      expect(
        RunningMetrics.calculateCalories(
          speed: 0,
          gradient: 10,
          elapsedSeconds: 3600,
        ),
        385,
      );
    });
  });
}
