# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Renthus Service** — a Brazilian local services marketplace (like GetNinjas). Clients post jobs, providers apply, clients choose a provider. MVP targets a single city.

Stack: **Flutter** (frontend) + **Supabase** (Auth, Postgres, RLS, Realtime, Storage, Edge Functions) + **Firebase** (FCM push notifications).

Monetization: Platform charges 15% per transaction; payment gateway fees are passed to the provider.

---

## Common Commands

```bash
# Run app
flutter run

# Code generation (Riverpod, Freezed, json_serializable) — run after any model/provider change
dart run build_runner build --delete-conflicting-outputs

# Lint
flutter analyze

# Tests
flutter test
flutter test test/path/to/specific_test.dart

# Regenerate launcher icons (after changing assets/images/app_icon.png)
dart run flutter_launcher_icons

# Regenerate splash screen
dart run flutter_native_splash:create

# Local Supabase
supabase start
supabase stop
supabase db reset        # reset local DB with migrations
supabase functions serve # serve Edge Functions locally
```

---

## Architecture

### Codebase Migration Status

The codebase is **mid-migration** from a legacy `setState`/`StatefulWidget` pattern to a Riverpod/`ConsumerWidget` pattern. Two coexisting structures:

- **`lib/screens/`** — legacy screens (being migrated). Some are still in use.
- **`lib/features/`** — new feature-first structure (migration target).

**New code must use `lib/features/`**. The migration convention is documented in `CURSOR_PROMPTS/CURSOR_MIGRATION_PROMPTS.md`.

### Feature Structure (target)

```
lib/features/[feature]/
  domain/models/       # Freezed immutable models + .g.dart + .freezed.dart
  data/repositories/   # Direct Supabase query logic
  data/providers/      # Riverpod @riverpod providers (+ .g.dart)
  presentation/pages/  # ConsumerWidget screens
```

Active features: `auth`, `jobs`, `chat`, `notifications`, `admin`, `profile`, `home`, `client`, `provider`.

### Core Layer (`lib/core/`)

- `router/app_router.dart` — GoRouter configuration + `AppRoutes` constants + `GoRouterExtensions` on `BuildContext` for type-safe navigation
- `services/auth_service.dart` — Supabase Auth wrapper
- `providers/supabase_provider.dart` — `supabaseProvider` (global `SupabaseClient` Riverpod provider)
- `providers/auth_provider.dart` — `currentUserProvider`
- `providers/cache_provider.dart` — Hive-backed cache
- `providers/notification_badge_provider.dart` — `NotificationBadgeController` singleton

### State Management (Riverpod)

All providers use `riverpod_annotation` with the `@riverpod` annotation. After editing any provider or model, run `build_runner`.

Pattern for async providers:
```dart
@riverpod
Future<SomeType> myProvider(MyProviderRef ref) async { ... }
```

Pattern for notifiers:
```dart
@riverpod
class MyActions extends _$MyActions {
  @override
  FutureOr<void> build() async {}
  // methods...
}
```

Always use `package:renthus/...` imports, never relative imports.

### Navigation

All routes are declared in `lib/core/router/app_router.dart`. Use the `BuildContext` extension methods (`context.goToClientHome()`, `context.pushJobDetails(id)`, etc.) rather than raw `go_router` calls.

Route data is passed via `state.extra as Map<String, dynamic>`.

### Database Access Pattern

Data is fetched directly from Supabase views (prefixed `v_`) using the `supabaseProvider`. Views handle joins and RLS:

Key views: `v_provider_me`, `v_client_me`, `v_provider_jobs_public`, `v_provider_my_jobs`, `v_client_jobs`, `v_client_my_jobs_dashboard`, `v_provider_disputes`, `v_client_job_quotes`, `v_client_job_payments`, and others listed in `docs/views.md`.

No raw table joins in the Flutter app — use views.

### Models

Use Freezed for domain models. After adding/editing `@freezed` classes, run `build_runner`. Generated files (`.freezed.dart`, `.g.dart`) are committed.

### Push Notifications

Firebase FCM + Supabase Edge Function (`supabase/functions/send-push/`). Device tokens are synced via `lib/services/fcm_device_sync.dart`. Navigation from push taps is handled in `lib/services/push_navigation_handler.dart`.

---

## Domain Model

**Job status flow:**
`waiting_providers` → `accepted` → `on_the_way` → `in_progress` → `completed`
(also: `cancelled`, `cancelled_by_client`, `cancelled_by_provider`, `execution_overdue`, `dispute`/`dispute_open`, `refunded`)

**Roles:** `client`, `provider`, `admin`. A user can hold both client and provider roles. Current role is tracked in `UserRoleHolder.currentRole`.

**Key tables:** `clients`, `providers`, `jobs`, `job_candidates`, `service_types`, `service_categories`, `provider_service_types`, `notifications`, `reviews`, `disputes`, `partner_banners`.

RLS enforces all access control — never rely solely on frontend guards for security.

---

## Environment

- `.env` file at project root (loaded via `flutter_dotenv`) — must contain `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Firebase config: `lib/firebase_options.dart` (generated by FlutterFire CLI).
- Local Supabase: port 54321 (API), 54322 (DB). See `supabase/config.toml`.
- Supabase project ref: `dqfejuakbtcxhymrxoqs`.

---

## Important Conventions

- **Never alter UI/layout when migrating screens** — only swap state management.
- Use `AsyncValue.when(data:, error:, loading:)` for async UI states.
- Locale is `pt_BR` — all user-facing strings are in Portuguese.
- Brand color: `#3B246B` (primary purple), `#FF6600` (accent orange).
- `useMaterial3: false` — the app uses Material 2 theme.
