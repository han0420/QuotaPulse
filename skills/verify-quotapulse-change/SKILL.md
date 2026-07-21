---
name: verify-quotapulse-change
description: Verify a QuotaPulse feature, bug fix, refactor, or documentation change before handoff or commit. Use when the user asks to verify, validate, finish, check readiness, review completion, or prepare a QuotaPulse change for commit.
---

# Verify a QuotaPulse change

Run from the repository root. Validate and report only; do not edit files, install the app, commit, push, or bypass failures unless the user separately requests those actions.

## Workflow

1. Inspect scope with `git status --short`, `git diff --stat`, and `git diff --check`. Preserve unrelated changes and distinguish staged from unstaged files.
2. Read the relevant file under `docs/specs/`. Confirm its status, requirements, acceptance scenarios, implementation mapping, verification notes, and unresolved manual checks match the implementation.
3. For user-visible behavior, confirm `README.md` is current. For ownership or data-flow changes, confirm `docs/ARCHITECTURE.md` is current. For privacy or credential changes, confirm `PRIVACY.md` and `docs/specs/credential-and-privacy.md` are current.
4. Check every changed user-visible localization key in both:
   - `Sources/QuotaPulse/Resources/en.lproj/Localizable.strings`
   - `Sources/QuotaPulse/Resources/zh-Hans.lproj/Localizable.strings`
5. Run the full test suite. If SwiftPM cache access is restricted, place caches under `.build` and request required permission:

   ```bash
   export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
   export SWIFTPM_CUSTOM_CACHE_PATH="$PWD/.build/swiftpm-cache"
   swift test
   ```

6. Run `./script/security_check.sh`. Treat any nonzero result as a failed check. If output is demonstrably pre-existing, report it separately as a repository blocker; never call the security check passed and never weaken the script to complete verification.
7. If the diff affects UI, app lifecycle, resources, entitlements, or packaging-sensitive behavior, run `./script/build_and_run.sh --verify` when GUI launch permission is available. Record any interaction that still needs manual verification.
8. If project skills changed, run `quick_validate.py` from the system `skill-creator` against each changed skill directory.
9. Re-run `git diff --check` and `git status --short`. Report changed scope, passed checks, failed checks, and manual checks not performed.

## Completion rule

Declare the change ready only when required automated checks pass, specs/docs/localizations are current, and no required work remains. A known or pre-existing failure is still a blocker under the repository definition of done; identify it precisely rather than hiding it.
