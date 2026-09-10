# RunningMate V2 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first RunningMate V2 vertical slice: a separate Flutter entry point with sports-racing home, HUD-first run screen, testable race logic, provider boundaries, and Supabase/Kakao-ready infrastructure.

**Architecture:** Keep the current app intact and add V2 under `lib/v2/` plus a separate `lib/main_v2.dart` entry point. Domain logic is pure Dart, repositories sit behind interfaces, UI reads state through Riverpod, and provider-specific Supabase/Kakao code stays behind adapters.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Supabase Flutter, Postgres/PostGIS migrations, Kakao Map SDK Flutter plugin, Geolocator.

---

## Scope Check

The redesign spec covers several independent systems: solo race, Supabase persistence, Kakao map integration, 1:1 rival races, and party run. This plan implements only the first shippable slice:

- V2 app entry point
- Today's Race card home
- HUD-first running screen
- Pure race, pace, ghost, and reward calculations
- Fake repository for local UI development
- Supabase schema foundation
- Kakao map adapter foundation

Rival Race and Party Run get separate implementation plans after this slice passes tests and runs on iPhone.

## File Structure

- `lib/main_v2.dart`: separate V2 entry point.
- `lib/v2/app/v2_app.dart`: Material app shell and theme.
- `lib/v2/app/v2_router.dart`: GoRouter route definitions.
- `lib/v2/core/config/v2_runtime_config.dart`: compile-time runtime config.
- `lib/v2/core/geo/geo_point.dart`: SDK-neutral latitude/longitude value object.
- `lib/v2/features/race/domain/race_models.dart`: race target, progress, ghost, reward models.
- `lib/v2/features/race/domain/race_calculator.dart`: pure race calculations.
- `lib/v2/features/race/data/race_repository.dart`: repository interface.
- `lib/v2/features/race/data/fake_race_repository.dart`: local fake repository.
- `lib/v2/features/race/providers/race_providers.dart`: Riverpod providers.
- `lib/v2/features/home/presentation/todays_race_screen.dart`: Race Card home.
- `lib/v2/features/run/presentation/running_hud_screen.dart`: HUD-first run screen.
- `lib/v2/features/map/presentation/race_map_preview.dart`: Kakao-ready map preview boundary.
- `supabase/migrations/20260616000000_runningmate_v2_foundation.sql`: PostGIS and MVP tables.
- `test/v2/...`: focused tests for config, race logic, fake repository, and UI smoke.

## Task 1: Add V2 Dependencies And Runtime Config

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/v2/core/config/v2_runtime_config.dart`
- Test: `test/v2/core/config/v2_runtime_config_test.dart`

- [ ] **Step 1: Add dependencies**

Run:

```bash
flutter pub add flutter_riverpod go_router supabase_flutter kakao_map_sdk
```

Expected: `pubspec.yaml` and `pubspec.lock` update successfully.

- [ ] **Step 2: Write the failing runtime config test**

Create `test/v2/core/config/v2_runtime_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/core/config/v2_runtime_config.dart';

void main() {
  group('V2RuntimeConfig', () {
    test('reports missing Supabase config when values are blank', () {
      const config = V2RuntimeConfig(
        supabaseUrl: '',
        supabaseAnonKey: '',
        kakaoNativeAppKey: '',
      );

      expect(config.hasSupabaseConfig, isFalse);
      expect(config.hasKakaoMapConfig, isFalse);
    });

    test('reports available provider config when values are present', () {
      const config = V2RuntimeConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        kakaoNativeAppKey: 'native-key',
      );

      expect(config.hasSupabaseConfig, isTrue);
      expect(config.hasKakaoMapConfig, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
flutter test test/v2/core/config/v2_runtime_config_test.dart
```

Expected: FAIL because `v2_runtime_config.dart` does not exist.

- [ ] **Step 4: Create runtime config**

Create `lib/v2/core/config/v2_runtime_config.dart`:

```dart
class V2RuntimeConfig {
  const V2RuntimeConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.kakaoNativeAppKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String kakaoNativeAppKey;

  static const current = V2RuntimeConfig(
    supabaseUrl: String.fromEnvironment('RUNNINGMATE_SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('RUNNINGMATE_SUPABASE_ANON_KEY'),
    kakaoNativeAppKey: String.fromEnvironment('RUNNINGMATE_KAKAO_NATIVE_KEY'),
  );

  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  bool get hasKakaoMapConfig => kakaoNativeAppKey.trim().isNotEmpty;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
flutter test test/v2/core/config/v2_runtime_config_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add pubspec.yaml pubspec.lock lib/v2/core/config/v2_runtime_config.dart test/v2/core/config/v2_runtime_config_test.dart
git commit -m "feat: add RunningMate v2 runtime config"
```

## Task 2: Add SDK-Neutral Geo Model

**Files:**
- Create: `lib/v2/core/geo/geo_point.dart`
- Test: `test/v2/core/geo/geo_point_test.dart`

- [ ] **Step 1: Write the failing geo test**

Create `test/v2/core/geo/geo_point_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/core/geo/geo_point.dart';

void main() {
  group('GeoPoint', () {
    test('rejects latitude outside valid range', () {
      expect(
        () => GeoPoint(latitude: 91, longitude: 127),
        throwsArgumentError,
      );
    });

    test('rejects longitude outside valid range', () {
      expect(
        () => GeoPoint(latitude: 37, longitude: 181),
        throwsArgumentError,
      );
    });

    test('serializes to json-safe map', () {
      final point = GeoPoint(latitude: 37.5665, longitude: 126.9780);

      expect(point.toJson(), {
        'latitude': 37.5665,
        'longitude': 126.978,
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/core/geo/geo_point_test.dart
```

Expected: FAIL because `geo_point.dart` does not exist.

- [ ] **Step 3: Create geo model**

Create `lib/v2/core/geo/geo_point.dart`:

```dart
class GeoPoint {
  GeoPoint({
    required this.latitude,
    required this.longitude,
  }) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'must be between -90 and 90');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'must be between -180 and 180');
    }
  }

  final double latitude;
  final double longitude;

  Map<String, double> toJson() {
    return <String, double>{
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/v2/core/geo/geo_point_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/v2/core/geo/geo_point.dart test/v2/core/geo/geo_point_test.dart
git commit -m "feat: add sdk-neutral geo point"
```

## Task 3: Add Race Domain And Calculations

**Files:**
- Create: `lib/v2/features/race/domain/race_models.dart`
- Create: `lib/v2/features/race/domain/race_calculator.dart`
- Test: `test/v2/features/race/domain/race_calculator_test.dart`

- [ ] **Step 1: Write the failing race calculator test**

Create `test/v2/features/race/domain/race_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/features/race/domain/race_calculator.dart';
import 'package:run1220/v2/features/race/domain/race_models.dart';

void main() {
  group('RaceCalculator', () {
    test('calculates pace seconds per kilometer', () {
      const progress = RaceProgress(
        distanceMeters: 1000,
        elapsedSeconds: 300,
      );

      expect(progress.paceSecondsPerKm, 300);
    });

    test('compares runner ahead of ghost', () {
      final comparison = RaceCalculator.compareGhost(
        runnerDistanceMeters: 1100,
        ghostDistanceMeters: 1000,
      );

      expect(comparison.status, GhostStatus.ahead);
      expect(comparison.gapMeters, 100);
    });

    test('creates reward for completed beginner race', () {
      const target = RaceTarget(
        id: 'starter-2k',
        title: '첫 2km 완주 레이스',
        distanceMeters: 2000,
        targetPaceSecondsPerKm: 450,
        baseXp: 120,
      );
      const progress = RaceProgress(
        distanceMeters: 2100,
        elapsedSeconds: 930,
      );

      final reward = RaceCalculator.completeRace(
        target: target,
        progress: progress,
      );

      expect(reward.completed, isTrue);
      expect(reward.xp, 120);
      expect(reward.badgeCode, 'starter_finish');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/features/race/domain/race_calculator_test.dart
```

Expected: FAIL because the race domain files do not exist.

- [ ] **Step 3: Create race models**

Create `lib/v2/features/race/domain/race_models.dart`:

```dart
enum GhostStatus {
  noGhost,
  ahead,
  behind,
  tied,
}

class RaceTarget {
  const RaceTarget({
    required this.id,
    required this.title,
    required this.distanceMeters,
    required this.targetPaceSecondsPerKm,
    required this.baseXp,
  });

  final String id;
  final String title;
  final double distanceMeters;
  final int targetPaceSecondsPerKm;
  final int baseXp;

  double get distanceKm => distanceMeters / 1000;
}

class RaceProgress {
  const RaceProgress({
    required this.distanceMeters,
    required this.elapsedSeconds,
  });

  final double distanceMeters;
  final int elapsedSeconds;

  double get distanceKm => distanceMeters / 1000;

  int? get paceSecondsPerKm {
    if (distanceMeters <= 0 || elapsedSeconds <= 0) {
      return null;
    }

    return (elapsedSeconds / distanceKm).round();
  }
}

class GhostComparison {
  const GhostComparison({
    required this.status,
    required this.gapMeters,
  });

  final GhostStatus status;
  final double gapMeters;
}

class RaceReward {
  const RaceReward({
    required this.completed,
    required this.xp,
    required this.badgeCode,
  });

  final bool completed;
  final int xp;
  final String? badgeCode;
}
```

- [ ] **Step 4: Create race calculator**

Create `lib/v2/features/race/domain/race_calculator.dart`:

```dart
import 'dart:math';

import 'race_models.dart';

class RaceCalculator {
  const RaceCalculator._();

  static GhostComparison compareGhost({
    required double runnerDistanceMeters,
    required double ghostDistanceMeters,
  }) {
    final gap = runnerDistanceMeters - ghostDistanceMeters;

    if (gap.abs() < 1) {
      return const GhostComparison(
        status: GhostStatus.tied,
        gapMeters: 0,
      );
    }

    return GhostComparison(
      status: gap > 0 ? GhostStatus.ahead : GhostStatus.behind,
      gapMeters: gap.abs(),
    );
  }

  static RaceReward completeRace({
    required RaceTarget target,
    required RaceProgress progress,
  }) {
    final completed = progress.distanceMeters >= target.distanceMeters;
    final completionRatio = progress.distanceMeters / target.distanceMeters;
    final earnedXp = completed
        ? target.baseXp
        : max(10, (target.baseXp * completionRatio * 0.5).round());

    return RaceReward(
      completed: completed,
      xp: earnedXp,
      badgeCode: completed ? 'starter_finish' : null,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
flutter test test/v2/features/race/domain/race_calculator_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/v2/features/race/domain test/v2/features/race/domain
git commit -m "feat: add v2 race domain"
```

## Task 4: Add Race Repository Boundary And Fake Data

**Files:**
- Create: `lib/v2/features/race/data/race_repository.dart`
- Create: `lib/v2/features/race/data/fake_race_repository.dart`
- Test: `test/v2/features/race/data/fake_race_repository_test.dart`

- [ ] **Step 1: Write failing repository test**

Create `test/v2/features/race/data/fake_race_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/features/race/data/fake_race_repository.dart';
import 'package:run1220/v2/features/race/domain/race_models.dart';

void main() {
  test('FakeRaceRepository returns beginner daily race', () async {
    final repository = FakeRaceRepository();

    final race = await repository.fetchTodaysRace();

    expect(race.id, 'starter-2k');
    expect(race.distanceMeters, 2000);
    expect(race.baseXp, 120);
  });

  test('FakeRaceRepository completes race with reward', () async {
    final repository = FakeRaceRepository();

    final reward = await repository.completeRace(
      const RaceProgress(distanceMeters: 2000, elapsedSeconds: 900),
    );

    expect(reward.completed, isTrue);
    expect(reward.xp, 120);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/features/race/data/fake_race_repository_test.dart
```

Expected: FAIL because repository files do not exist.

- [ ] **Step 3: Create repository interface**

Create `lib/v2/features/race/data/race_repository.dart`:

```dart
import '../domain/race_models.dart';

abstract interface class RaceRepository {
  Future<RaceTarget> fetchTodaysRace();

  Future<RaceReward> completeRace(RaceProgress progress);
}
```

- [ ] **Step 4: Create fake repository**

Create `lib/v2/features/race/data/fake_race_repository.dart`:

```dart
import '../domain/race_calculator.dart';
import '../domain/race_models.dart';
import 'race_repository.dart';

class FakeRaceRepository implements RaceRepository {
  static const beginnerRace = RaceTarget(
    id: 'starter-2k',
    title: '첫 2km 완주 레이스',
    distanceMeters: 2000,
    targetPaceSecondsPerKm: 450,
    baseXp: 120,
  );

  @override
  Future<RaceTarget> fetchTodaysRace() async {
    return beginnerRace;
  }

  @override
  Future<RaceReward> completeRace(RaceProgress progress) async {
    return RaceCalculator.completeRace(
      target: beginnerRace,
      progress: progress,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
flutter test test/v2/features/race/data/fake_race_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/v2/features/race/data test/v2/features/race/data
git commit -m "feat: add v2 race repository boundary"
```

## Task 5: Add Riverpod Providers

**Files:**
- Create: `lib/v2/features/race/providers/race_providers.dart`
- Test: `test/v2/features/race/providers/race_providers_test.dart`

- [ ] **Step 1: Write provider test**

Create `test/v2/features/race/providers/race_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/features/race/providers/race_providers.dart';

void main() {
  test('todaysRaceProvider exposes starter race', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final race = await container.read(todaysRaceProvider.future);

    expect(race.id, 'starter-2k');
    expect(race.title, '첫 2km 완주 레이스');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/features/race/providers/race_providers_test.dart
```

Expected: FAIL because providers do not exist.

- [ ] **Step 3: Create providers**

Create `lib/v2/features/race/providers/race_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_race_repository.dart';
import '../data/race_repository.dart';
import '../domain/race_models.dart';

final raceRepositoryProvider = Provider<RaceRepository>((ref) {
  return FakeRaceRepository();
});

final todaysRaceProvider = FutureProvider<RaceTarget>((ref) async {
  return ref.watch(raceRepositoryProvider).fetchTodaysRace();
});
```

- [ ] **Step 4: Run provider test to verify it passes**

Run:

```bash
flutter test test/v2/features/race/providers/race_providers_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/v2/features/race/providers test/v2/features/race/providers
git commit -m "feat: add v2 race providers"
```

## Task 6: Add Today's Race Home, HUD Screens, And V2 Router

**Files:**
- Create: `lib/v2/app/v2_router.dart`
- Create: `lib/v2/app/v2_app.dart`
- Create: `lib/v2/features/home/presentation/todays_race_screen.dart`
- Create: `lib/v2/features/run/presentation/running_hud_screen.dart`
- Test: `test/v2/features/home/presentation/todays_race_screen_test.dart`

- [ ] **Step 1: Write home screen smoke test**

Create `test/v2/features/home/presentation/todays_race_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/app/v2_app.dart';

void main() {
  testWidgets('Today race screen shows race card CTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: RunningMateV2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S RACE"), findsOneWidget);
    expect(find.text('첫 2km 완주 레이스'), findsOneWidget);
    expect(find.text('레이스 시작'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/features/home/presentation/todays_race_screen_test.dart
```

Expected: FAIL because presentation screens do not exist.

- [ ] **Step 3: Create Today's Race screen**

Create `lib/v2/features/home/presentation/todays_race_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../race/providers/race_providers.dart';

class TodaysRaceScreen extends ConsumerWidget {
  const TodaysRaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final race = ref.watch(todaysRaceProvider);

    return Scaffold(
      body: SafeArea(
        child: race.when(
          data: (target) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RunningMate',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Text('Bronze III'),
                  ],
                ),
                const Spacer(),
                const Text(
                  "TODAY'S RACE",
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  target.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${target.distanceKm.toStringAsFixed(1)}km / 목표 페이스 ${_formatPace(target.targetPaceSecondsPerKm)}',
                  style: const TextStyle(color: Color(0xFFC9D1D9)),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Metric(label: 'DIST', value: '${target.distanceKm.toStringAsFixed(1)}km'),
                      _Metric(label: 'PACE', value: _formatPace(target.targetPaceSecondsPerKm)),
                      _Metric(label: 'XP', value: '+${target.baseXp}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/run'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: const Text(
                      '레이스 시작',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          error: (error, stackTrace) => Center(child: Text('레이스를 불러오지 못했습니다: $error')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  static String _formatPace(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "$minutes'${remainingSeconds.toString().padLeft(2, '0')}\"";
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Create HUD screen**

Create `lib/v2/features/run/presentation/running_hud_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RunningHudScreen extends StatelessWidget {
  const RunningHudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.close),
                  ),
                  const Text('LIVE RACE'),
                ],
              ),
              const Spacer(),
              const Text(
                'PACE',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Text(
                "7'30\"",
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: const [
                  Expanded(child: _HudMetric(label: 'DIST', value: '0.42km')),
                  SizedBox(width: 12),
                  Expanded(child: _HudMetric(label: 'TIME', value: '03:08')),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 150,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Kakao Map Preview'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('일시정지'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                      child: const Text('완료'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run widget test to verify it passes**

Run:

```bash
flutter test test/v2/features/home/presentation/todays_race_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/v2/features/home lib/v2/features/run test/v2/features/home
git commit -m "feat: add v2 race card home"
```

## Task 7: Add V2 Entry Point

**Files:**
- Create: `lib/main_v2.dart`
- Modify: `lib/v2/app/v2_app.dart`
- Test: `test/v2/app/v2_app_test.dart`

- [ ] **Step 1: Write app smoke test**

Create `test/v2/app/v2_app_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/app/v2_app.dart';

void main() {
  testWidgets('RunningMateV2App boots to Today Race', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: RunningMateV2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RunningMate'), findsOneWidget);
    expect(find.text("TODAY'S RACE"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test**

Run:

```bash
flutter test test/v2/app/v2_app_test.dart
```

Expected: PASS after Task 6.

- [ ] **Step 3: Create V2 main entry point**

Create `lib/main_v2.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'v2/app/v2_app.dart';
import 'v2/core/config/v2_runtime_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = V2RuntimeConfig.current;

  if (config.hasSupabaseConfig) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }

  if (config.hasKakaoMapConfig) {
    await KakaoMapSdk.instance.initialize(config.kakaoNativeAppKey);
  }

  runApp(
    ProviderScope(
      child: RunningMateV2App(),
    ),
  );
}
```

- [ ] **Step 4: Run V2 tests**

Run:

```bash
flutter test test/v2
```

Expected: PASS.

- [ ] **Step 5: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: No new issues from `lib/v2` or `lib/main_v2.dart`. If existing app files report unrelated issues, record the exact file names before changing anything.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/main_v2.dart test/v2/app/v2_app_test.dart
git commit -m "feat: add RunningMate v2 entry point"
```

## Task 8: Add Kakao Map Preview Boundary

**Files:**
- Create: `lib/v2/features/map/presentation/race_map_preview.dart`
- Modify: `lib/v2/features/run/presentation/running_hud_screen.dart`
- Test: `test/v2/features/map/presentation/race_map_preview_test.dart`

- [ ] **Step 1: Write map preview fallback test**

Create `test/v2/features/map/presentation/race_map_preview_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run1220/v2/features/map/presentation/race_map_preview.dart';
import 'package:run1220/v2/core/config/v2_runtime_config.dart';

void main() {
  testWidgets('RaceMapPreview shows fallback without Kakao key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RaceMapPreview(
            config: V2RuntimeConfig(
              supabaseUrl: '',
              supabaseAnonKey: '',
              kakaoNativeAppKey: '',
            ),
          ),
        ),
      ),
    );

    expect(find.text('지도 준비 중'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/v2/features/map/presentation/race_map_preview_test.dart
```

Expected: FAIL because `race_map_preview.dart` does not exist.

- [ ] **Step 3: Create map preview boundary**

Create `lib/v2/features/map/presentation/race_map_preview.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../../core/config/v2_runtime_config.dart';

class RaceMapPreview extends StatelessWidget {
  const RaceMapPreview({
    required this.config,
    super.key,
  });

  final V2RuntimeConfig config;

  @override
  Widget build(BuildContext context) {
    if (!config.hasKakaoMapConfig) {
      return const _MapFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: KakaoMap(
        option: const KakaoMapOption(
          position: LatLng(37.5665, 126.9780),
          zoomLevel: 16,
          mapType: MapType.normal,
        ),
        onMapReady: (controller) {},
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('지도 준비 중'),
    );
  }
}
```

- [ ] **Step 4: Replace HUD static map text with boundary**

In `lib/v2/features/run/presentation/running_hud_screen.dart`, add imports:

```dart
import '../../../core/config/v2_runtime_config.dart';
import '../../map/presentation/race_map_preview.dart';
```

Replace the static map preview container with:

```dart
const RaceMapPreview(config: V2RuntimeConfig.current),
```

- [ ] **Step 5: Run map preview test**

Run:

```bash
flutter test test/v2/features/map/presentation/race_map_preview_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/v2/features/map lib/v2/features/run/presentation/running_hud_screen.dart test/v2/features/map
git commit -m "feat: add Kakao-ready race map preview"
```

## Task 9: Add Supabase PostGIS Foundation Migration

**Files:**
- Create: `supabase/migrations/20260616000000_runningmate_v2_foundation.sql`

- [ ] **Step 1: Create migration**

Create `supabase/migrations/20260616000000_runningmate_v2_foundation.sql`:

```sql
create extension if not exists postgis with schema extensions;

create table if not exists public.runner_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Runner',
  runner_grade text not null default 'bronze_iii',
  total_xp integer not null default 0 check (total_xp >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.run_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  race_target_id text not null,
  distance_meters numeric not null check (distance_meters >= 0),
  elapsed_seconds integer not null check (elapsed_seconds >= 0),
  average_pace_seconds_per_km integer,
  earned_xp integer not null default 0 check (earned_xp >= 0),
  completed boolean not null default false,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.run_points (
  id bigint generated always as identity primary key,
  run_record_id uuid not null references public.run_records(id) on delete cascade,
  point_index integer not null check (point_index >= 0),
  recorded_at timestamptz not null,
  location geography(point, 4326) not null,
  accuracy_meters numeric,
  created_at timestamptz not null default now(),
  unique (run_record_id, point_index)
);

create index if not exists run_points_location_idx
  on public.run_points
  using gist (location);

create table if not exists public.race_results (
  id uuid primary key default gen_random_uuid(),
  run_record_id uuid not null references public.run_records(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_code text,
  ghost_status text not null default 'no_ghost',
  ghost_gap_meters numeric not null default 0,
  created_at timestamptz not null default now()
);

alter table public.runner_profiles enable row level security;
alter table public.run_records enable row level security;
alter table public.run_points enable row level security;
alter table public.race_results enable row level security;

create policy "runner_profiles_select_own"
  on public.runner_profiles
  for select
  using (auth.uid() = id);

create policy "runner_profiles_insert_own"
  on public.runner_profiles
  for insert
  with check (auth.uid() = id);

create policy "runner_profiles_update_own"
  on public.runner_profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "run_records_select_own"
  on public.run_records
  for select
  using (auth.uid() = user_id);

create policy "run_records_insert_own"
  on public.run_records
  for insert
  with check (auth.uid() = user_id);

create policy "run_points_select_own"
  on public.run_points
  for select
  using (
    exists (
      select 1
      from public.run_records
      where run_records.id = run_points.run_record_id
        and run_records.user_id = auth.uid()
    )
  );

create policy "run_points_insert_own"
  on public.run_points
  for insert
  with check (
    exists (
      select 1
      from public.run_records
      where run_records.id = run_points.run_record_id
        and run_records.user_id = auth.uid()
    )
  );

create policy "race_results_select_own"
  on public.race_results
  for select
  using (auth.uid() = user_id);

create policy "race_results_insert_own"
  on public.race_results
  for insert
  with check (auth.uid() = user_id);
```

- [ ] **Step 2: Validate migration syntax**

Run:

```bash
supabase db lint
```

Expected: PASS. If the Supabase CLI is missing, install it before continuing with this task.

- [ ] **Step 3: Commit**

Run:

```bash
git add supabase/migrations/20260616000000_runningmate_v2_foundation.sql
git commit -m "feat: add RunningMate v2 Supabase foundation"
```

## Task 10: Run Foundation Verification

**Files:**
- Review: `lib/v2/**`
- Review: `test/v2/**`
- Review: `supabase/migrations/20260616000000_runningmate_v2_foundation.sql`

- [ ] **Step 1: Run V2 tests**

Run:

```bash
flutter test test/v2
```

Expected: PASS.

- [ ] **Step 2: Run all Flutter tests**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 3: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS or only pre-existing non-V2 issues listed with file paths.

- [ ] **Step 4: Run V2 app on iPhone or simulator**

Run:

```bash
flutter run -t lib/main_v2.dart -d 00008110-000A022E2E89401E
```

Expected: app opens to the Race Card home screen and the `레이스 시작` CTA navigates to the HUD screen.

- [ ] **Step 5: Commit verification note**

If verification required a documentation note, create `docs/superpowers/plans/2026-06-16-runningmate-v2-foundation-verification.md` with the exact command results. Then run:

```bash
git add docs/superpowers/plans/2026-06-16-runningmate-v2-foundation-verification.md
git commit -m "docs: record RunningMate v2 foundation verification"
```

If every verification result is already visible in task commits, skip this commit.

## Self-Review

Spec coverage:

- Guest-first entry is supported by `lib/main_v2.dart` and fake repository because the V2 app boots without login.
- Today's Race home is covered by Task 6.
- HUD-first running screen is covered by Task 6.
- Race, pace, ghost, and reward calculations are covered by Task 3.
- Supabase/PostGIS foundation is covered by Task 9.
- Kakao map boundary is covered by Task 8.
- Rival Race and Party Run are deliberately separated into future plans because the spec marks Party Run outside MVP and Rival Race after the solo slice.

Placeholder scan:

- The plan contains concrete file paths, commands, tests, and code snippets for each implementation step.
- No incomplete requirement marker is used.

Type consistency:

- `RaceTarget`, `RaceProgress`, `RaceReward`, and `GhostComparison` are defined in Task 3 and used consistently by repository, provider, and UI tasks.
- `V2RuntimeConfig.current` is defined in Task 1 and used by the V2 entry point and map preview.
- `RaceRepository` is defined before provider usage.
