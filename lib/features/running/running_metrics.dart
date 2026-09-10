class RunningMetrics {
  const RunningMetrics._();

  static String formatPace({
    required int elapsedSeconds,
    required double distanceMeters,
  }) {
    final distanceInKm = distanceMeters / 1000;
    if (distanceInKm <= 0) return '--:--';

    final paceSeconds = elapsedSeconds / distanceInKm;
    final minutes = paceSeconds ~/ 60;
    final seconds = (paceSeconds % 60).round();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  static double calculateCalories({
    required double speed,
    required double gradient,
    required int elapsedSeconds,
    double weightKg = 70.0,
  }) {
    var met = 1.5;

    if (speed >= 12.0) {
      met = 12.0;
    } else if (speed >= 8.0) {
      met = 10.0;
    } else if (speed >= 5.0) {
      met = 6.0;
    } else if (speed >= 3.0) {
      met = 3.0;
    }

    if (gradient >= 5) {
      met += 1.5;
    }
    if (gradient >= 10) {
      met += 2.5;
    }
    if (gradient < -5) {
      met -= 1.0;
    }

    final timeInHours = elapsedSeconds / 3600.0;
    return met * weightKg * timeInHours;
  }
}
