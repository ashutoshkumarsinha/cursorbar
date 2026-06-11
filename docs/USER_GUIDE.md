# CursorBar — User Guide

CursorBar is a macOS menu bar app that shows your Cursor AI usage at a glance: remaining Fast Requests, optional pay-as-you-go spending, and per-model token totals. It runs quietly in the background and updates on a schedule you choose.

CursorBar does **not** appear in the Dock. Look for the bolt icon in the top-right menu bar.

---

## 1. Getting Started

### Install from source (Xcode)

1. Clone the repository:
   ```bash
   git clone https://github.com/ashutoshkumarsinha/cursorbar.git
   cd cursorbar
   ```
2. Open the project:
   ```bash
   open CursorBar.xcodeproj
   ```
3. In Xcode, select your **Development Team** under **Signing & Capabilities**.
4. Press **⌘R** to build and run.

On first launch, CursorBar opens a **Connect CursorBar** window. You can set up authentication now or click **Skip for Now** and configure it later.

### What you need

| Requirement | Details |
|-------------|---------|
| macOS | 14.0 or later |
| Xcode | 15.0 or later (for building from source) |
| Cursor account | Active subscription at [cursor.com](https://cursor.com) |
| Browser session | Signed in to cursor.com in Safari, Chrome, or another browser |

---

## 2. Connecting Your Account

Cursor does not provide a public API key for billing. CursorBar uses the same session cookie your browser uses when you are logged in to cursor.com.

### Find your session token

1. Open [cursor.com](https://cursor.com) and sign in.
2. Open your browser’s developer tools:
   - **Chrome / Edge:** `⌥⌘I` (Option + Command + I)
   - **Safari:** Enable **Develop** menu in Settings, then **Develop → Show Web Inspector**
   - **Firefox:** `⌥⌘I`
3. Go to the **Application** tab (Chrome) or **Storage** tab (Firefox).
4. Under **Cookies**, select `https://cursor.com` (or `www.cursor.com`).
5. Find the cookie named **`WorkosCursorSessionToken`**.
6. Copy its **Value** (the long string — not the name).

### Save the token in CursorBar

**First-run onboarding**

1. Paste the token into the secure field.
2. Click **Save & Connect**.

**Later, via Preferences**

1. Click the CursorBar menu bar icon.
2. Click **Preferences…** in the popover footer.
3. Paste the token into **WorkosCursorSessionToken**.
4. Click **Save Token**.

CursorBar stores the token in the **macOS Keychain** only. It is never saved to a plain text file or sent anywhere except cursor.com when syncing usage.

### Sign out / remove token

1. Open **Preferences…**
2. Click **Clear Token**.

The menu bar switches to a warning state until you add a new token.

---

## 3. Reading the Menu Bar

The menu bar item shows a bolt icon and a short status value.

### Normal display (default)

```
⚡ 350
```

The number is your **remaining Fast Requests** for the current billing cycle.

### Spending display (optional)

If you enable **Show spending in menu bar** in Preferences:

```
⚡ $4.52
```

This shows your current optional pay-as-you-go spend instead of request count.

### Status colors

| Color | Meaning |
|-------|---------|
| **Green** | Healthy quota — more than 20% of Fast Requests remain |
| **Orange** | Low quota (under 20% remaining) or optional spend is at 80%+ of your limit |
| **Red** | Critical — fewer than 50 Fast Requests remain |
| **Grey** | Session expired, sync failed, or still loading |

### Warning states

| Label | Meaning |
|-------|---------|
| `Auth` | No token saved, or session expired — re-authenticate in Preferences |
| `…` | Syncing in progress |
| `—` | Network or server error — open the popover and retry |

---

## 4. Using the Popover

Click the menu bar icon to open the usage panel.

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

### Header

- **Title** — remaining requests, plan name, or error state
- **Sync button** (↻) — fetch the latest usage immediately

### Usage sections

| Section | What it shows |
|---------|---------------|
| **Plan row** | Your subscription tier (Free, Pro, Business, etc.) and days left in the billing cycle |
| **Fast Requests** | Progress bar and `used / total` count |
| **Optional Pay-As-You-Go Spending** | Current spend vs. your configured spending cap |
| **Model Breakdown** | Token usage per model for the current cycle |

Token counts are formatted for readability (e.g. `1.57M` for 1,570,000 tokens).

### Footer actions

| Button | Action |
|--------|--------|
| **Preferences…** | Open settings (token, refresh interval, display mode) |
| **Quit App** | Exit CursorBar completely |

---

## 5. Preferences

Open **Preferences…** from the popover footer.

### Authentication

| Control | Purpose |
|---------|---------|
| **WorkosCursorSessionToken** field | Paste a new or updated session token |
| **Save Token** | Store token in Keychain and start syncing |
| **Clear Token** | Remove token and stop background polling |

### Polling

| Setting | Options | Default |
|---------|---------|---------|
| **Refresh Interval** | Every 5, 15, or 30 minutes | 15 minutes |
| **Show spending in menu bar** | On / Off | Off (shows request count) |

Changes take effect immediately. Updating the refresh interval restarts the background poll timer.

### About

Shows app version and the API endpoint CursorBar uses (`cursor.com/api/usage`).

---

## 6. How Background Sync Works

CursorBar fetches usage data on a timer and when you click **Sync Now**.

| Behavior | Detail |
|----------|--------|
| **Automatic polling** | Runs at your chosen interval (5 / 15 / 30 min) |
| **Manual sync** | Always available via the ↻ button in the popover |
| **While refreshing** | Last successful data stays visible until the new fetch completes |
| **Mac asleep** | Polling pauses to save network and battery |
| **Mac wakes** | CursorBar syncs immediately, then resumes polling |

CursorBar is designed to use negligible CPU when idle. Network activity happens only during scheduled or manual syncs.

---

## 7. Troubleshooting

### Menu bar shows `Auth` or “Session Expired”

Your browser session cookie has expired or was never saved.

1. Sign in to [cursor.com](https://cursor.com) in your browser.
2. Copy a fresh `WorkosCursorSessionToken` (see [§2](#2-connecting-your-account)).
3. Open **Preferences…** → paste token → **Save Token**.

### Menu bar shows `—` or “Unable to Sync”

A network or server error occurred.

1. Check your internet connection.
2. Click the menu bar icon and press **Retry** (or use the ↻ sync button).
3. Confirm [cursor.com](https://cursor.com) is reachable in your browser.

If the problem persists, Cursor may have changed their API. Check the [project repository](https://github.com/ashutoshkumarsinha/cursorbar) for updates.

### Token saved but numbers look wrong

- Click **Sync Now** to force a fresh fetch.
- Compare with the usage shown in the Cursor web dashboard.
- Ensure you copied the full cookie value with no extra spaces.

### CursorBar is not in the Dock

This is expected. CursorBar is a menu bar agent (`LSUIElement`). It only appears in the menu bar.

To quit: open the popover → **Quit App**.

To relaunch: run from Xcode (⌘R) or open the built `CursorBar.app`.

### macOS blocks the app on first open

If you distribute a built `.app` outside the App Store, macOS may warn about an unidentified developer.

1. Open **System Settings → Privacy & Security**.
2. Click **Open Anyway** for CursorBar, or right-click the app → **Open**.

### Keychain save failed

Rare, but can happen with restrictive security policies.

1. Ensure CursorBar has permission to use the Keychain (allow when macOS prompts).
2. Try **Clear Token**, then paste and **Save Token** again.
3. Rebuild from Xcode with your Development Team selected.

---

## 8. Privacy & Security

| Topic | CursorBar behavior |
|-------|------------------|
| **What is stored** | Session token in macOS Keychain; refresh interval and display preference in `UserDefaults` (or defaults from `~/.cursorbar/config.toml`) |
| **What is sent** | One HTTPS request to `www.cursor.com/api/usage` with your session cookie |
| **What is not sent** | Token to third parties, analytics services, or cloud storage |
| **Token scope** | Equivalent to staying logged in on cursor.com — protect it like a password |

Do not share your `WorkosCursorSessionToken`. If you suspect it was exposed, sign out of cursor.com in your browser (which invalidates the session) and generate a new token.

---

## 9. FAQ

**Does CursorBar work without Cursor IDE open?**  
Yes. It only needs a valid cursor.com session token and network access.

**Can I use multiple Cursor accounts?**  
Not in v1. One token per installation. Switch accounts by clearing the token and saving a new one.

**Will CursorBar notify me when quota is low?**  
Not in v1. Watch the menu bar color (orange/red) or open the popover for details.

**How often should I refresh?**  
15 minutes is a good default. Use 5 minutes if you are running heavy agent workloads; 30 minutes if you want fewer network calls.

**Is this an official Cursor product?**  
No. CursorBar is an independent open-source utility. It is not affiliated with or endorsed by Cursor.

---

## 10. Related Documents

- [Functional Specification (SPEC)](SPEC.md)
- [README](../README.md)
- [GitHub repository](https://github.com/ashutoshkumarsinha/cursorbar)
