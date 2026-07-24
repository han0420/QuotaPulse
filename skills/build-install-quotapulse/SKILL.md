---
name: build-install-quotapulse
description: Build and install the current QuotaPulse macOS app into /Applications/QuotaPulse.app. Use when the user asks to compile, package, install, or refresh the locally installed QuotaPulse app.
---

# Build and install QuotaPulse

Use this skill for local development installation requests such as “编译安装新版本” or “安装到 `/Applications/QuotaPulse.app`”. Work from the repository root.

## Workflow

1. Inspect `git status --short`; preserve unrelated user changes.
2. Build the app bundle with the repository-owned script:

   ```bash
   export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
   export SWIFTPM_CUSTOM_CACHE_PATH="$PWD/.build/swiftpm-cache"
   export QUOTAPULSE_ALLOW_ADHOC=1
   ./script/assemble_app.sh debug "$PWD/dist/QuotaPulse.app"
   ```

   Use `release` only when the user explicitly requests a release build. Release signing/notarization follows `docs/RELEASING.md`.

3. Verify the generated bundle with `codesign --verify --deep --strict --verbose=2`.
4. With explicit user authorization, replace `/Applications/QuotaPulse.app` with the verified bundle. This is an external filesystem write and may require escalation:

   ```bash
   rm -rf /Applications/QuotaPulse.app
   cp -R "$PWD/dist/QuotaPulse.app" /Applications/QuotaPulse.app
   codesign --verify --deep --strict --verbose=2 /Applications/QuotaPulse.app
   ```

   Do not keep a backup copy of the previous app bundle unless the user explicitly asks for one.

5. Report the installed path, bundle identifier, version/build number, and whether ad-hoc signing was used.

## Safety and validation

- Never copy tokens, Keychain contents, or user data into the app bundle.
- Do not use `git reset`, broad deletion, or install to a different path without user direction.
- Ad-hoc signing is for local execution only; it is not suitable for public distribution.
- If the build fails, stop at the failing step and report the exact error instead of installing a partial bundle.
- For UI/resource/lifecycle changes, run `./script/build_and_run.sh --verify` when the environment permits opening the app; otherwise report that manual launch verification was not performed.
