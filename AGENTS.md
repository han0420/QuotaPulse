# AGENTS.md — QuotaPulse repository guide

This file is the entry point for AI coding agents. It applies to the entire repository. User instructions take precedence; more deeply nested `AGENTS.md` files, if added later, override this file only within their directory.

## Mission and boundaries

QuotaPulse is a native macOS 14+ Swift 6 / SwiftUI menu bar app that displays Codex and Claude quota, activity, reset information, weather-backed visuals, and notifications. It reads local authenticated sessions and calls provider endpoints directly. Do not introduce an account relay, analytics, telemetry, remote configuration, or a new backend without an explicit privacy/security decision.

Never expose or commit tokens, credential files, Keychain contents, usernames, exact coordinates, private keys, signing material, or personal absolute paths. Preserve the direct-service and local-first privacy model.

## Start here

Read, in order:

1. `docs/README.md` — documentation index.
2. `docs/ARCHITECTURE.md` — boundaries, data flow, and component ownership.
3. `docs/SPEC_WORKFLOW.md` — mandatory spec-first workflow.
4. The relevant file under `docs/specs/`.
5. Existing implementation and tests for the affected area.

## Mandatory spec-first workflow

Every new feature and user-visible behavior change MUST follow `docs/SPEC_WORKFLOW.md`:

1. Create or update `docs/specs/<feature-name>.md` before editing production code.
2. Record goals, non-goals, requirements, boundaries, acceptance scenarios, technical approach, and test plan.
3. Resolve materially ambiguous product/security choices with the user. For clear requests, document minimal assumptions and continue.
4. Write focused tests and run them to observe the expected RED failure.
5. Implement the minimum change that makes the tests GREEN, then refactor.
6. Run the full verification suite.
7. Mark the spec `Implemented`, add implementation mapping, and update affected docs.

Do not silently diverge from an accepted spec. Bug fixes should update an existing spec or add a compact regression spec when no suitable document exists.

## Repository map

```text
Sources/QuotaPulse/
  App/        App lifecycle, menu bar scene, dependency composition
  Models/     Domain models and persisted configuration
  Services/   Provider, notification, weather, location, login-item clients
  Stores/     Refresh orchestration, merging, observable state, alert triggers
  Views/      SwiftUI menu bar, floating panel, settings, visual components
  Support/    Formatting, theme, localization state, window control
  Resources/  en and zh-Hans localization plus image assets
Tests/QuotaPulseTests/  XCTest behavior, policy, parsing, and regression coverage
docs/                 Architecture, specs, install, and release documentation
script/               Build/run, security, assets, packaging, and release tools
skills/               Project-local Codex skills for repeatable repository workflows
```

## Project-local skills

When the user asks to compile or install a new local version of the app, use [`skills/build-install-quotapulse/SKILL.md`](skills/build-install-quotapulse/SKILL.md). It standardizes building `QuotaPulse.app`, verifying its signature, and installing it to `/Applications/QuotaPulse.app`; installation requires explicit user authorization because it writes outside the repository and replaces the existing app.

When adding or changing SwiftUI settings, forms, inputs, toggles, buttons, or other user-visible controls, use [`skills/quotapulse-ui-guidelines/SKILL.md`](skills/quotapulse-ui-guidelines/SKILL.md) and follow [`docs/UI_GUIDELINES.md`](docs/UI_GUIDELINES.md). This keeps new UI consistent with the existing grouped Form layout, localization, and save/status patterns.

Before handing off, declaring completion, or preparing a change for commit, use [`skills/verify-quotapulse-change/SKILL.md`](skills/verify-quotapulse-change/SKILL.md). It checks specs, affected docs, both localizations, the full test suite, security audit, conditional app launch verification, project skill validity, and git hygiene; it reports blockers but does not edit, install, commit, or push.

Key ownership:

- `QuotaPulseApp.swift` (`QuotaPulseApp`): lifecycle and shared dependency construction.
- `QuotaStore.swift`: source refresh, provider merge, quota state, activity, threshold dispatch.
- `QuotaModels.swift`: provider/window models and quota health.
- `QuotaNotificationConfiguration.swift`: configurable quota-alert policy and persistence.
- `DailyReminderConfiguration.swift`: scheduled reminders and click actions.
- `SettingsView.swift`: all persistent settings UI.
- `FloatingQuotaView.swift`: primary floating interface.
- `CodexDirectClient.swift` / `ClaudeDirectClient.swift`: direct provider integrations.
- `QuotaNotificationService.swift`: macOS notification delivery and scheduling.

## Architecture rules

- Keep domain policy testable without SwiftUI, AppKit, or live network calls.
- `QuotaStore` coordinates data; views render state and emit user intent. Views do not call quota endpoints directly.
- Services own external I/O. Pass process arguments structurally; do not construct shell commands from user input.
- Persist lightweight preferences in `UserDefaults` with safe defaults and backward-compatible decoding.
- Do not overwrite one provider with stale fallback data after its direct client succeeds.
- Preserve the first-reading baseline behavior: alerts compare subsequent readings, not app-launch state.
- Add every user-visible string to both `en.lproj` and `zh-Hans.lproj`.
- Keep macOS deployment compatibility at the version declared in `Package.swift` unless the spec explicitly changes it.

## Working commands

Run from repository root:

```bash
swift test
./script/security_check.sh
./script/build_and_run.sh --verify
```

`swift test` is the minimum completion check. Run `security_check.sh` for every completed change. Use `build_and_run.sh --verify` when UI, app lifecycle, resources, entitlements, or packaging-sensitive behavior changes. Release work additionally follows `docs/RELEASING.md`.

If SwiftPM cannot write its user cache in a sandbox, point `CLANG_MODULE_CACHE_PATH` and `SWIFTPM_CUSTOM_CACHE_PATH` at subdirectories under `.build`; request the required execution permission rather than bypassing validation.

## Testing expectations

- Follow RED → GREEN → REFACTOR; do not write production behavior before a failing test.
- Test public behavior and real policy objects, not private implementation details.
- Parsing changes need sanitized fixtures or constructed inputs.
- Persistence changes need default, round-trip, invalid-data, and migration coverage as applicable.
- Threshold/time boundary behavior needs exact edge-case tests.
- UI-only behavior that cannot be unit tested requires explicit manual checks in its spec.

## Change hygiene

- The worktree may contain user changes. Inspect `git status` and diffs; preserve unrelated work.
- Keep changes focused on the active spec. Do not opportunistically refactor unrelated code.
- Use `rg` / `rg --files` for discovery and `apply_patch` for manual edits.
- Never use destructive git or filesystem commands without explicit authorization.
- Update `README.md` for user-visible features, `docs/ARCHITECTURE.md` for ownership/data-flow changes, and the relevant spec for behavior changes.
- Do not commit or push unless the user explicitly requests it.

## Definition of done

A change is complete only when the spec is current, acceptance scenarios are satisfied, tests pass, security checks pass, both localizations are present, affected documentation is updated, and the final response reports verification plus any manual checks not performed.
