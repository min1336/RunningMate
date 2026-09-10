# RunningMate Best Practices Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the existing RunningMate Flutter app behavior while rebuilding the project structure around clear bootstrap, configuration, theme, auth, and verification boundaries.

**Architecture:** Keep the current screen widgets intact for the first pass, then move cross-cutting app concerns out of `main.dart`. Treat the `lib/` folder as the source of truth and reconcile root-level Dart copies only after checking feature differences.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, Firebase Auth, Cloud Firestore, Naver Map, Geolocator, audioplayers.

---

### Task 1: Stabilize The App Entry Point

**Files:**
- Create: `lib/app/running_mate_app.dart`
- Create: `lib/app/auth_gate.dart`
- Create: `lib/app/app_bootstrap.dart`
- Create: `lib/core/config/naver_map_config.dart`
- Create: `lib/core/theme/app_theme.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Move initialization into `app_bootstrap.dart`**

Create a bootstrap function that initializes Flutter bindings, Naver Map, Firebase, and Korean date formatting in one place.

- [ ] **Step 2: Move `MaterialApp` into `running_mate_app.dart`**

Keep title, theme, and home route behavior identical.

- [ ] **Step 3: Move auth stream logic into `auth_gate.dart`**

Keep the existing email-verification gate and destination screens unchanged.

- [ ] **Step 4: Run `flutter analyze`**

Expected: root-level stale Dart files may still produce errors, but the new bootstrap files must not add new errors.

### Task 2: Add Project Hygiene

**Files:**
- Create: `.gitignore`
- Create: `analysis_options.yaml`

- [ ] **Step 1: Ignore local/generated files**

Ignore `.dart_tool/`, `.flutter-plugins-dependencies`, build output, IDE files, and `.DS_Store`.

- [ ] **Step 2: Enable Flutter lints carefully**

Include `package:flutter_lints/flutter.yaml`, but defer broad warning cleanup to later tasks.

### Task 3: Reconcile Root Dart Copies

**Files:**
- Review: root-level `*.dart`
- Review: matching `lib/*.dart`

- [ ] **Step 1: Identify root-only features**

Known examples: `recommended_routes_slider.dart`, ghost runner fields in root `running_screen.dart`.

- [ ] **Step 2: Port useful features into `lib/`**

Move features only after the matching `lib/` screen can analyze cleanly.

- [ ] **Step 3: Remove stale root copies**

Delete root-level Dart copies once their useful behavior is either preserved in `lib/` or explicitly rejected.

### Task 4: Extract Testable Running Logic

**Files:**
- Create: `lib/features/running/running_metrics.dart`
- Create: `test/features/running/running_metrics_test.dart`
- Modify: `lib/running_screen.dart`

- [ ] **Step 1: Extract pure pace/time/calorie helpers**

Keep UI and Naver Map code inside `running_screen.dart`; move deterministic calculations into a small pure Dart helper.

- [ ] **Step 2: Add tests for no-distance pace, regular pace, and calorie rounding**

Run: `flutter test test/features/running/running_metrics_test.dart`

### Task 5: Android Execution Recovery

**Files:**
- Review: `android/local.properties`
- Review: Android SDK installation

- [ ] **Step 1: Install Android SDK locally**

Required before `flutter build apk --debug` can pass.

- [ ] **Step 2: Run Android smoke test**

Run: `flutter build apk --debug`, then `flutter run` on emulator or device.
