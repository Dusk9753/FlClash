# FlClash XBoard Client Handoff

## Scope

This repository is the branded FlClash client for Android, Windows, and macOS.
It integrates the client with the platform's user authentication, subscription,
announcements, plans, and payment workflows. The underlying proxy core remains
the upstream FlClash/ClashMeta architecture and must not be replaced as part of
XBoard feature work.

## Stable Git Baseline

- Branch: `main`
- Last committed product change: `9077540 ui: improve announcements and plan purchase flow`
- Remote: `origin` points to the project GitHub repository.
- The repository contains pending user work that is intentionally not committed
  with this handoff. Preserve it until it is reviewed and verified as one
  focused feature.

## Pending Working Tree

Tracked source changes currently cover Android release packaging, client
navigation, startup prompts, and an XBoard support entry point. They have not
received a full Flutter or native verification pass.

Untracked APK, ZIP, `artifacts/`, and `support.html` files are local outputs or
work-in-progress inputs. Do not stage release artifacts by wildcard. Review each
file explicitly before deciding whether it belongs in source control or a GitHub
release.

## Required Reading

1. `AGENTS.md`
2. `.agents/project.md`
3. `.agents/commands.md`
4. `.agents/rules.md`
5. `TODO.md`

`docs/XBOARD_CLIENT_PLAN.md` is an ignored historical planning note. Treat it as
background only; do not copy endpoint details, credentials, or deployment
configuration into source, commits, tests, or user-facing UI.

## Architecture Boundaries

- Authentication, XBoard API calls, and remote data models belong in
  `lib/features/auth/` and `lib/features/xboard/`.
- Subscription import must continue through the existing profile action rather
  than duplicating proxy-profile persistence.
- Desktop process lifecycle ownership stays under `lib/core/desktop/`.
- Android service lifecycle ownership stays in native `ServiceState`; Flutter
  requests transitions but does not arbitrate them.
- Never expose platform management endpoints, upstream URLs, auth headers,
  subscription tokens, UUIDs, raw backend failures, or payment provider details
  to ordinary users.

## Verification Before a Feature Commit

Run from the repository root when the local SDK and dependencies are available:

```bash
git submodule update --init --recursive
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

Run focused tests for the changed layer and code generation after changing
models, Riverpod providers, or database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For Go-wrapper changes:

```bash
cd core
CGO_ENABLED=0 go test .
CGO_ENABLED=0 go vet .
```

Android, Windows, and macOS release artifacts require their respective native
toolchains. A host-only Flutter test does not verify VPN permissions, Windows
service behavior, packaging, signing, or platform update handling.

## Commit Discipline

- Keep one feature or fix per commit, with focused tests where behavior changes.
- Stage exact paths; never use `git add .` in this checkout.
- Do not commit generated local build directories, APK/ZIP outputs, tokens,
  endpoints, payment payloads, or local environment files.
- Push only reviewed commits. Confirm the pushed branch and remote SHA after
  every push.