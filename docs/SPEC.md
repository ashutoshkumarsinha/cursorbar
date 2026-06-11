# Functional Specification: CursorBar

**Product:** CursorBar  
**Platform:** macOS 14+  
**Repository:** [github.com/ashutoshkumarsinha/cursorbar](https://github.com/ashutoshkumarsinha/cursorbar)  
**Status:** Implemented (v1.0.0)

---

## 1. Product Overview

CursorBar is a lightweight, open-source macOS menu bar utility that lets developers monitor Cursor AI usage without leaving their workflow. It surfaces remaining Fast Requests, optional pay-as-you-go spending, and per-model token consumption directly from the system menu bar.

### 1.1 Problem Statement

Developers using Cursor IDE frequently exhaust Fast Requests or incur unexpected usage-based charges mid-task—often due to background agent loops or heavy context loading. Checking quota today requires breaking focus, opening a browser, and navigating the Cursor Settings Dashboard.

### 1.2 Goals

- Display remaining Fast Requests (or spend) at a glance in the menu bar
- Provide a compact usage breakdown on click (plan, quota bar, model tokens, optional spend)
- Poll Cursor's backend on a configurable interval with minimal CPU/memory overhead
- Store authentication credentials only in the macOS Keychain
- Degrade gracefully when the session expires or the network is unavailable

### 1.3 Non-Goals (v1)

- Windows/Linux ports
- Official Cursor API integration (no public consumer API key exists)
- In-app browser login or OAuth flow
- Push notifications or macOS Notification Center alerts
- Historical usage charts or export
- Multi-account support

---

## 2. Functional Requirements

### 2.1 Menu Bar Gauge

| ID | Requirement | Status |
|----|-------------|--------|
| MG-01 | Show custom logo + remaining Fast Request count in menu bar (default) | ✅ |
| MG-02 | Optional toggle to show optional spend (`$X.XX`) instead of request count | ✅ |
| MG-03 | Green status when > 20% fast-request quota remains and spend is below warning threshold | ✅ |
| MG-04 | Orange status when < 20% quota remains OR ≥ 80% of optional spend limit used | ✅ |
| MG-05 | Red status when < 50 fast requests remain | ✅ |
| MG-06 | Grey warning icon when session expired or network/sync error | ✅ |
| MG-07 | App runs as menu bar agent (`LSUIElement`; no Dock icon) | ✅ |

### 2.2 Dropdown Popover

| ID | Requirement | Status |
|----|-------------|--------|
| PO-01 | Click menu bar item to open compact popover (320pt wide) | ✅ |
| PO-02 | Header shows plan summary, e.g. `⚡ 350 Left (Pro)` | ✅ |
| PO-03 | Manual **Sync Now** button in header | ✅ |
| PO-04 | Subscription row: plan tier + days left in billing cycle | ✅ |
| PO-05 | Fast Request progress bar: used / total | ✅ |
| PO-06 | Optional pay-as-you-go meter: current / max spend | ✅ |
| PO-07 | Model breakdown list with human-readable names and formatted token totals | ✅ |
| PO-08 | Footer: **Preferences…** and **Quit App** | ✅ |
| PO-09 | Session-expired callout with link to Preferences | ✅ |
| PO-10 | Network error view with message and **Retry** | ✅ |

### 2.3 Authentication

| ID | Requirement | Status |
|----|-------------|--------|
| AU-01 | First-run onboarding sheet when no token is stored | ✅ |
| AU-02 | User pastes `WorkosCursorSessionToken` from browser cookies | ✅ |
| AU-03 | Token stored in Keychain (`kSecClassGenericPassword`) | ✅ |
| AU-04 | Token never written to plaintext files or external servers | ✅ |
| AU-05 | Preferences UI to save or clear token | ✅ |
| AU-06 | 401/403 API responses transition UI to session-expired state | ✅ |

### 2.4 Polling & Background Behavior

| ID | Requirement | Status |
|----|-------------|--------|
| PB-01 | Configurable refresh interval: 5, 15, or 30 minutes (default 15) | ✅ |
| PB-02 | Background polling loop via `Task` + `Task.sleep` | ✅ |
| PB-03 | Pause polling when Mac sleeps (`NSWorkspace.willSleepNotification`) | ✅ |
| PB-04 | On wake: immediate sync + resume polling | ✅ |
| PB-05 | Manual sync bypasses sleep guard only when awake | ✅ |
| PB-06 | Refresh keeps last good data visible while re-fetching | ✅ |

### 2.5 Preferences

| ID | Requirement | Status |
|----|-------------|--------|
| PR-01 | Secure field for session token entry | ✅ |
| PR-02 | Save Token / Clear Token actions | ✅ |
| PR-03 | Refresh interval picker | ✅ |
| PR-04 | Toggle: show spending vs. requests in menu bar | ✅ |
| PR-05 | Preferences persisted in `UserDefaults`; `config.toml` supplies defaults | ✅ |

---

## 3. User Interface

### 3.1 Menu Bar Label

```
⚡ 350          (requests remaining — default)
⚡ $4.52        (optional spend — when toggled)
⚠️ Auth         (session expired)
…               (loading)
—               (network error)
```

Rendered via `MenuBarLabelView` embedded in `NSStatusItem.button` using `NSHostingView`.

### 3.2 Popover Layout

```
+----------------------------------------+
| ⚡ 350 Left (Pro Plan)     [🔄 Sync]   |
+----------------------------------------+
| Fast Requests                          |
| [====================------] 150 / 500 |
|                                        |
| Optional Pay-As-You-Go Spending        |
| $4.52 / $20.00 Max                     |
|                                        |
| Model Breakdown (Current Cycle):       |
|  • Claude 4.6 Opus: 1.57M tokens     |
|  • GPT-5 Fast:      0.56M tokens     |
+----------------------------------------+
| Preferences…               Quit App    |
+----------------------------------------+
```

### 3.3 Onboarding Sheet

Shown on first launch when Keychain has no token:

1. Explain privacy model (Keychain-only storage)
2. Step-by-step instructions to copy `WorkosCursorSessionToken` from DevTools
3. Secure paste field
4. **Save & Connect** or **Skip for Now**

### 3.4 Gauge Color Logic

Evaluated in `GaugeStatus.from(usage:)` (first match wins):

| Priority | Condition | Color |
|----------|-----------|-------|
| 1 | `fastRequestsRemaining < 50` | Red |
| 2 | `fastRequestsQuotaPercentRemaining < 20%` | Orange |
| 3 | `optionalSpendingPercentUsed >= 80%` (when limit > 0) | Orange |
| 4 | Otherwise | Green |

Non-success states map to grey **warning** (expired session, network error) or **loading**.

---

## 4. Authentication & Security

### 4.1 Token Source

Cursor does not expose a public billing API key. CursorBar authenticates using the user's browser session cookie:

| Property | Value |
|----------|-------|
| Cookie name | `WorkosCursorSessionToken` |
| Source | [cursor.com](https://cursor.com) → DevTools → Application → Cookies |
| Transmission | `Cookie` HTTP header on API requests |

### 4.2 Keychain Storage

| Property | Value |
|----------|-------|
| Class | `kSecClassGenericPassword` |
| Service | `com.cursorbar.session` |
| Account | `WorkosCursorSessionToken` |
| Accessibility | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |

Implementation: `KeychainService.swift`

### 4.3 Entitlements

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.app-sandbox` | App Sandbox enabled |
| `com.apple.security.network.client` | Outbound HTTPS to cursor.com |

### 4.4 Threat Model Notes

- Token is equivalent to a logged-in browser session; treat like a password
- No telemetry, analytics, or third-party network calls in v1
- UserDefaults stores only non-sensitive preferences (interval, display mode)

---

## 5. Network & API

### 5.1 Endpoint

```
GET https://www.cursor.com/api/usage HTTP/1.1
Host: www.cursor.com
Cookie: WorkosCursorSessionToken=<token>
User-Agent: CursorBar/1.0 (macOS; Native Utility)
```

Implementation: `CursorAPIService.swift`

### 5.2 Response Schema

```json
{
  "subscriptionPlan": "Pro",
  "daysLeftInPeriod": 12,
  "fastRequestsUsed": 150,
  "fastRequestsTotal": 500,
  "optionalSpendingLimit": 20.00,
  "optionalSpendingCurrent": 4.52,
  "modelBreakdown": [
    {
      "modelName": "claude-4.6-opus",
      "inputTokens": 1250000,
      "outputTokens": 320000
    },
    {
      "modelName": "gpt-5-fast",
      "inputTokens": 450000,
      "outputTokens": 110000
    }
  ]
}
```

Mapped to `UsageResponse` and `ModelUsage` in `Models/UsageData.swift`.

### 5.3 HTTP Status Handling

| Status | Behavior |
|--------|----------|
| 200 | Decode JSON → `FetchState.success` |
| 401, 403 | `FetchState.sessionExpired` |
| Other | `FetchState.networkError` with status code |
| Decode failure | `FetchState.networkError` with decode message |

### 5.4 API Stability

The `/api/usage` endpoint and JSON shape are **not officially documented** by Cursor. This spec reflects the expected dashboard contract. If Cursor changes the API, update `UsageResponse` and `CursorAPIService` accordingly.

---

## 6. Data Model

### 6.1 `UsageResponse`

| Field | Type | Description |
|-------|------|-------------|
| `subscriptionPlan` | String | Plan tier (e.g. Free, Pro, Business) |
| `daysLeftInPeriod` | Int | Days until billing cycle reset |
| `fastRequestsUsed` | Int | Fast requests consumed this cycle |
| `fastRequestsTotal` | Int | Fast request quota for cycle |
| `optionalSpendingLimit` | Double | Max optional pay-as-you-go spend |
| `optionalSpendingCurrent` | Double | Current optional spend |
| `modelBreakdown` | `[ModelUsage]` | Per-model token usage |

**Computed:**

- `fastRequestsRemaining` = `max(0, total - used)`
- `fastRequestsQuotaPercentRemaining`
- `optionalSpendingPercentUsed`

### 6.2 `ModelUsage`

| Field | Type | Description |
|-------|------|-------------|
| `modelName` | String | API model identifier |
| `inputTokens` | Int | Input tokens this cycle |
| `outputTokens` | Int | Output tokens this cycle |

**Display aliases** (extensible map in code):

| API name | Display name |
|----------|--------------|
| `claude-4.6-opus` | Claude 4.6 Opus |
| `gpt-5-fast` | GPT-5 Fast |
| `gpt-5` | GPT-5 |
| `gemini-3.1-pro` | Gemini 3.1 Pro |

### 6.3 `FetchState`

| Case | Meaning |
|------|---------|
| `idle` | Initial state before first fetch |
| `loading` | Sync in progress |
| `success(UsageResponse)` | Valid data available |
| `sessionExpired` | Missing or rejected token |
| `networkError(String)` | Transport, HTTP, or decode failure |

### 6.4 User Preferences

Runtime preferences load from `config.toml` (`~/.cursorbar/config.toml` or `CURSORBAR_CONFIG`). Values changed in the Preferences UI are stored in `UserDefaults` and override file defaults.

**`UserDefaults` keys (current implementation):**

| Key | Type | Default |
|-----|------|---------|
| `cursorbar.refreshInterval` | Int (minutes) | `15` |
| `cursorbar.displaySpending` | Bool | `false` |

**`config.toml` schema (see `config.toml.example`):**

| Section | Key | Type | Default |
|---------|-----|------|---------|
| `[app]` | `version` | int | `1` |
| `[polling]` | `refresh_interval_minutes` | int | `15` (5, 15, or 30) |
| `[polling]` | `pause_on_sleep` | bool | `true` |
| `[polling]` | `sync_on_wake` | bool | `true` |
| `[menu_bar]` | `display_spending` | bool | `false` |
| `[api]` | `base_url` | string | `https://www.cursor.com/api/usage` |
| `[api]` | `user_agent` | string | `CursorBar/1.0 (macOS; Native Utility)` |
| `[gauge]` | `red_requests_remaining` | int | `50` |
| `[gauge]` | `orange_quota_percent` | int | `20` |
| `[gauge]` | `orange_spend_percent` | int | `80` |
| `[logging]` | `level` | string | `info` |

Default config directory: `~/.cursorbar/`  
Override: environment variable `CURSORBAR_CONFIG` (path to `config.toml`).

---

## 7. Architecture

### 7.1 Stack

| Layer | Technology |
|-------|------------|
| Menu bar anchor | AppKit `NSStatusItem` |
| Popover host | AppKit `NSPopover` + `NSHostingController` |
| UI | SwiftUI |
| State | `UsageStore` (`ObservableObject`, `@MainActor`) |
| Networking | `URLSession` (async/await) |
| Secrets | Security framework / Keychain Services |
| Sleep detection | `NSWorkspace` notifications |

### 7.2 Component Map

```
CursorBarApp (@main)
└── AppDelegate
    ├── UsageStore          ← central observable state
    └── StatusBarController ← NSStatusItem + NSPopover
        ├── MenuBarLabelView
        ├── PopoverContentView
        ├── PreferencesView (window)
        └── AuthenticationView (onboarding window)

Services
├── KeychainService         ← token CRUD
├── CursorAPIService        ← HTTP client
├── SleepMonitor            ← sleep/wake hooks
└── UsageStore              ← polling orchestration
```

### 7.3 Source Layout

```
CursorBar/
├── App/
│   ├── CursorBarApp.swift
│   └── AppDelegate.swift
├── Controllers/
│   └── StatusBarController.swift
├── Models/
│   └── UsageData.swift
├── Services/
│   ├── CursorAPIService.swift
│   ├── KeychainService.swift
│   ├── SleepMonitor.swift
│   └── UsageStore.swift
├── Views/
│   ├── AuthenticationView.swift
│   ├── MenuBarLabelView.swift
│   ├── PopoverContentView.swift
│   └── PreferencesView.swift
└── Resources/
    ├── Info.plist          (LSUIElement = true)
    ├── CursorBar.entitlements
    └── Assets.xcassets
```

### 7.4 Lifecycle

1. **Launch** — `AppDelegate` creates `UsageStore` and `StatusBarController`
2. **No token** — show onboarding; menu bar shows warning state
3. **Token present** — immediate `syncNow()`, start polling loop
4. **Sleep** — cancel polling task
5. **Wake** — `syncNow()` + restart polling
6. **Quit** — terminate via popover footer; no persistent background daemon

---

## 8. Non-Functional Requirements

| ID | Requirement | Target | Notes |
|----|-------------|--------|-------|
| NF-01 | Memory footprint | < 35 MB RAM | Menu bar agent; no heavy frameworks |
| NF-02 | Idle CPU | ~0% | Logic runs only on poll interval or manual sync |
| NF-03 | Startup time | < 2 s to menu bar visible | No splash window |
| NF-04 | Error tolerance | No crash on auth/network failure | Graceful `FetchState` transitions |
| NF-05 | Privacy | No external data exfiltration | Only cursor.com API calls |

---

## 9. Build & Development

### 9.1 Requirements

| Tool | Version |
|------|---------|
| macOS | 14.0+ |
| Xcode | 15.0+ |
| Swift | 5.0+ |

### 9.2 Open & Run

```bash
git clone https://github.com/ashutoshkumarsinha/cursorbar.git
cd cursorbar
open CursorBar.xcodeproj
```

1. Select a **Development Team** under Signing & Capabilities
2. Build and run (`⌘R`)
3. Paste session token when prompted

### 9.3 Devbox

```bash
devbox shell    # optional reproducible dev environment
```

`devbox.json` is initialized; add packages as needed (e.g. lint tooling).

### 9.4 Bundle Metadata

| Property | Value |
|----------|-------|
| Bundle ID | `com.cursorbar.app` |
| Version | `1.0.0` (build `1`) |
| Category | Developer Tools |
| Agent app | Yes (`LSUIElement`) |

### 9.5 Distribution (Future)

v1 is source-first via Xcode. For public release:

1. Archive in Xcode (Release)
2. Sign with Apple Developer ID
3. Notarize via `notarytool`
4. Distribute `.dmg` or `.zip`

---

## 10. Future Enhancements (Backlog)

| ID | Feature |
|----|---------|
| FU-01 | Native cookie import helper (reduced manual DevTools steps) |
| FU-02 | macOS Notification Center alerts at quota thresholds |
| FU-03 | Menu bar sparkline / historical usage chart |
| FU-04 | Launch at login (SMAppService) |
| FU-05 | Multi-workspace / multi-account profiles |
| FU-06 | ~~CI workflow (GitHub Actions)~~ | ✅ |
| FU-07 | ~~Onboarding flow integration tests~~ | ✅ |

---

## 11. Related Documents

- [User Guide](USER_GUIDE.md)
- [README](../README.md)
- Repository: [github.com/ashutoshkumarsinha/cursorbar](https://github.com/ashutoshkumarsinha/cursorbar)
