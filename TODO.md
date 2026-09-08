# FlClash XBoard Client TODO

## P0: Verify and Finish Pending Client Work

- Review the pending Android release native-library packaging change on a clean
  Android release build.
- Verify the pending support navigation and external-link flow on Android,
  Windows, and macOS without leaking support-provider or backend failure data.
- Decide whether the removed startup disclaimer and diagnostics prompts are a
  product requirement change; restore required compliance or consent behavior
  before release.
- Separate local APK/ZIP/artifact files from source changes and publish only
  through the intended release channel.

## P1: XBoard Customer Journey

- Complete authenticated account lifecycle: registration, password recovery,
  session expiry, logout, and clear recoverable error states.
- Show subscription status, traffic, expiry, device limit, and plan details
  using platform-approved presentation data.
- Complete plans, order creation, payment-method selection, external payment or
  QR presentation, cancellation, status polling, and paid-order refresh.
- Make announcement display resilient to malformed or unavailable remote data.
- Add customer support and order-help flows with accessible loading, failure,
  retry, and external-launch states.

## P2: Delivery and Reliability

- Add focused tests for auth state, XBoard models/client failures, payment state
  transitions, and subscription import handoff.
- Verify releases on Android, Windows, and macOS with the CI-pinned Flutter
  version and native toolchains.
- Confirm version/update configuration and client download routing use approved
  platform-owned data and do not reveal infrastructure details.
- Define release signing, artifact checksum, GitHub release, rollback, and
  customer support procedures outside source-controlled runtime configuration.

## Guardrails

- Do not turn XBoard client work into a parallel lifecycle owner for the proxy
  core or Android service.
- Do not persist or log raw access tokens, subscription links, UUIDs, payment
  payloads, backend response headers, or upstream error bodies.
- Use server-controlled configuration and customer-safe error messages.