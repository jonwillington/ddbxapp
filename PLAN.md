# ddbx-app — dashboard plan & notes

Context: reinterpret [dd-site](https://github.com/) (Director Dealings web app) for the iOS app **ddbx-app**. Focus on the **dashboard** (trades only), not portfolio or user accounts. Match **colours and font** where possible; prefer **native SwiftUI**; add libraries only when they clearly help.

---

## What dd-site does (dashboard-relevant)

### Data / API

| Endpoint | Purpose |
|----------|---------|
| `GET /api/dealings` | List of `Dealing` rows (`worker/db/types.ts`: `trade_date`, `disclosed_date`, director, `ticker`, `company`, `tx_type`, `value_gbp`, optional `triage`, optional `analysis` with `rating`, `summary`, etc.). |
| `GET /api/version` | `{ latest, totyehal }` from DB. Dashboard polls every **30s** and refetches when fingerprint `latest:total` changes (`use-data-version.ts`). |
| `GET /api/prices/latest?tickers=…` | Latest prices for tickers + `^FTAS`. |
| `GET /api/prices/history?ticker=^FTAS&days=365` | FTSE history for “performance vs FTSE” hero. |
| `GET /api/news/uk` | UK headlines strip (trading days). Optional for a “pure trades” v1. |

### “Analysed” vs noise

- **`isSuggestedDealing`** (`dealing-classify.ts`): `analysis` exists **and** `analysis.rating !== "routine"`. Other rows are clustered as “skipped” on the web.

### Twitter-style summaries (conceptual)

- `worker/pipeline/twitter.ts`: per-deal tweets and **session summaries** (`Session`: `"morning" | "afternoon"`) via `buildDailySummaryTweet`. Same *ideas* as push: **notable purchase** vs **mid-session** vs **close** copy.

### Visual language (`globals.css` + dashboard)

- **Font:** **Instrument Sans** (primary), with system fallbacks.
- **Light:** warm paper — e.g. `#f5f0e8`, `#faf7f2`, borders `#e8e0d5`, accent brown **`#6b5038`**, secondary browns/tans in the hero.
- **Dark:** warm browns via **oklch** (see `globals.css`: `--background`, `--surface`, `--muted`, etc.).
- **Returns:** oklch greens/reds for positive/negative lines (see dashboard hero).

---

## Project naming

- Repo folder: **`ddbx-app`** (`/Users/jonwillington/ddbx-app`).
- Swift package/target/module: **`DdbxApp`** (no hyphens in module names). User-visible name can still be “ddbx” / “ddbx-app” via display name / assets later.

---

## Phased plan

### Phase 1 — Shell + design system ✅

- Xcode project via xcodegen (`.xcodeproj` with entitlements, asset catalog).
- Tokenised `Theme.swift` with light (warm paper) + dark (warm brown oklch) color tokens.
- `Typography.swift` — Instrument Sans (all 8 weights) via `Font.instrument()`.
- Appearance toggle (System / Light / Dark) in toolbar.

### Phase 2 — Read-only dashboard ✅

- `APIClient` hitting `https://api.ddbx.uk/api` — `dealings()`, `dealing(id:)`, `version()`.
- Codable `Models.swift` matching `Dealing`, `Analysis`, `DirectorSummary`, `Rating`, etc.
- `DashboardViewModel` with 30s version polling + fingerprint diffing.
- Dashboard: Today (analysed vs skipped) + History grouped by month.
- `DealRow` — ticker chip (mono), company, director, GBP value, rating badge.
- `DealDetailView` — sheet with key fields, analysis, thesis, risks, performance.
- Pull-to-refresh.

### Phase 3 — Notable purchase push ✅

- **Worker (`dd-site`):**
  - `worker/pipeline/apns.ts` — ES256 JWT signing (Web Crypto), APNs sender, auto-deactivates stale tokens.
  - `POST /api/devices` + `DELETE /api/devices` in `worker/index.ts`.
  - `device_tokens` D1 table (Migration 004).
  - Hooked into `run.ts` — fires alongside Twitter for significant/noteworthy deals.
- **App (`ddbx-app`):**
  - `PushManager.swift` — permission request, device token registration to server.
  - `AppDelegate.swift` — UIKit push delegate bridge.
  - `DdbxApp.entitlements` — `aps-environment: development`.
- **To go live:** APNs key (.p8) + `wrangler secret put` for `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`. Run D1 migration. Set Xcode Development Team.

### Phase 4 — Morning / close digest ✅

- `sendDigestPush()` in `apns.ts` — builds concise title (session, trade count, total value) + top 3 tickers body.
- Fires in parallel with `postDailySummary()` tweet at 12:30 UTC (morning) and 17:30 UTC (close) crons.
- Digest push uses `thread-id: daily-digest` (separate from deal alerts).
- Notification taps: `PushManager` implements `UNUserNotificationCenterDelegate`; tapping a deal notification opens the detail sheet (fetches from API if not in local cache).
- Foreground display: banners shown even when app is open.

### Phase 5 — Polish

- `BGAppRefreshTask` to poll `version` occasionally (does not replace push for real-time alerts).
- Accessibility: Dynamic Type, VoiceOver on rows.

### Out of scope (for now)

- Portfolio, full evidence tables, user accounts (device token table is enough for push).

---

## Security note (dd-site repo)

`worker/pipeline/twitter.ts` has contained **live API credentials** in the past. Store secrets in **environment variables**, rotate any exposed keys, and avoid committing credentials.
