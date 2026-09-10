# RunningMate V2 Redesign

Date: 2026-06-16

## Goal

RunningMate V2 is a simple sports racing app for beginner runners.

The app should help a beginner know what to run today, start quickly, complete a short race, and feel measurable progress through racing-style feedback.

## Product Direction

The product tone is sports racing and runner club, not cute RPG or fantasy.

Core promise:

- Give the user a clear daily race.
- Make running feel like a race against a target, ghost, or friend.
- Keep beginner friction low by allowing the first run without signup.
- Save progress, ranking, and social features after account creation.

## Confirmed Stack

- App: Flutter
- State management: Riverpod
- Routing: GoRouter
- Backend: Supabase
- Auth: Supabase Auth
- Database: Supabase Postgres
- Geospatial data: PostGIS
- Storage: Supabase Storage
- Map: Kakao Map Flutter plugin first
- Place search: Kakao Local REST API through a Supabase Edge Function
- Future realtime: Supabase Realtime for party run presence/progress

## Strategy

This is a full rewrite, but the rewrite should still be staged.

The first implementation target is not feature parity with the current app. The first target is a clean MVP that proves the new product loop:

1. Open app.
2. See today's race.
3. Start running.
4. Track distance, time, and pace.
5. Compete against a simple ghost or target pace.
6. Finish the run.
7. See race report and rewards.
8. Sign up to save history.

## MVP Scope

Included:

- Optional login
- Guest-first app entry
- Today's Race home screen
- Running HUD screen
- Kakao Map route display
- Current location tracking
- Distance, duration, and pace calculation
- Basic ghost runner or target pace comparison
- Race completion report
- XP, badge, and runner grade feedback
- Supabase-backed saving after signup

Excluded from MVP:

- Real-time party run
- Real-time 1:1 race
- Full shop system
- Marathon admin tools
- Complex character growth
- Fantasy-style worldbuilding
- Advanced fraud detection

## Home Screen

Selected layout: Race Card.

The home screen should answer one question immediately: what should I run today?

Primary hierarchy:

1. Runner identity and grade
2. Today's Race label
3. Race title
4. Target distance
5. Target pace
6. Expected duration
7. XP or badge reward
8. Start Race CTA

The map should not dominate the home screen. Map detail belongs mainly in the running flow.

## Running Screen

Selected layout: HUD-first with map support.

Primary hierarchy:

1. Pace
2. Distance
3. Time
4. Ghost or target comparison
5. Pause and finish actions
6. Map preview and route trace

The user should not need to stare at a map while running. The running screen should be glanceable.

## Game Modes

RunningMate should eventually support three game layers:

### 1. Solo Race

The beginner's core mode.

- Today's race
- Target pace
- Personal best comparison
- Ghost runner from previous runs
- Completion report

### 2. Rival Race

Asynchronous competition.

- 1:1 challenge
- Same distance or same route comparison
- Friend ghost
- Result sharing
- League points

### 3. Party Run

Group running mode.

- Room creation
- Friend invite
- Group mission
- Realtime progress
- Presence and race status through Supabase Realtime

Party Run is not part of the MVP.

## Data Boundaries

Flutter screens should not directly depend on Supabase tables or Kakao SDK classes.

The rewrite should introduce boundaries such as:

- `AuthRepository`
- `RunRepository`
- `RaceRepository`
- `QuestRepository`
- `RewardRepository`
- `MapService`
- `PlaceSearchService`
- `RouteService`

These boundaries keep provider decisions replaceable and make the app testable.

## Suggested Supabase Domains

Initial domains:

- users
- runner_profiles
- run_records
- run_points
- races
- race_results
- quests
- rewards
- badges
- friendships

PostGIS should be used for location and route-point data that needs distance, nearby search, or route filtering.

## Security And Keys

Kakao REST API keys should not be called directly from the Flutter client for server-like operations.

Use a Supabase Edge Function for:

- Kakao Local API calls
- Future route recommendation calls
- Any API call requiring a secret or quota control

Supabase Row Level Security must be enabled for user-owned records before production use.

## Testing And Verification

Minimum gates for implementation:

- `flutter analyze`
- `flutter test`
- iOS simulator run
- physical iPhone run when map/location changes
- Supabase local migration validation once schemas are introduced

Core logic that should have unit tests:

- distance calculation
- pace calculation
- race completion summary
- ghost comparison
- XP/reward calculation

## Open Decisions

These should be decided during implementation planning:

- Which Kakao Map Flutter plugin to use first
- Exact Supabase schema
- Exact guest-to-user account linking behavior
- MVP ghost runner rules
- XP and runner grade formula
- Race report visual design

