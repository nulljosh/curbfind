# Architecture

Craigslist browser stripped of clutter. Web (Cloudflare Worker), iOS/macOS (native SwiftUI), Android/desktop (Kotlin Multiplatform). iOS and macOS query Craigslist directly; the web app proxies through a Cloudflare Worker for CORS and caching. "Best deals" sort is the one exception: it ranks results against each search's own median price and uses Workers AI to write deal reasons, so all four platforms route this sort through the worker.

## How it runs

**Web:** User navigates to curbfind.heyitsmejosh.com, gets static HTML from a Cloudflare Page. `onboarding.js` loads the UI. A search fires a fetch to the worker at `/api/search` with query params (city, category, sort, filters). The worker translates that to Craigslist's undocumented sapi endpoint, caches responses for five minutes in Workers KV, and applies `rankByDeal` + AI deal reasons if sort=deal before returning JSON.

**iOS/macOS:** App launches, creates a `SearchModel`. User enters filters and searches. `SearchFilters.city` is resolved to a Craigslist area ID via `AreaDirectory`, which caches these forever (they never change). `CraigslistAPI.search()` builds a request to `sapi.craigslist.org/web/v8/postings` and calls `decodeSearch()` to turn positional arrays into real `Listing` objects. For "best deals" sort, the app calls `searchDeals()` instead, which routes through the worker for AI ranking.

**Android/desktop:** Kotlin Multiplatform Compose UI calling the worker's `/api/search` endpoint over HTTP, same as the web app.

**TUI:** SwiftPM executable (`tui/main.swift`) reusing `CraigslistAPI` and `Listing` directly, no sort or filter UI, hardcoded to take city and query from command line.

## Decoding

Craigslist's sapi returns search results as positional arrays indexed against a per-response decode dictionary. Both `CraigslistAPI.swift` and `worker/decode.js` do the same job and are pinned by a shared `worker/fixtures/search.json` fixture to never drift apart.

| File | What it owns |
|---|---|
| `Sources/Models/CraigslistAPI.swift` | Talks to Craigslist sapi directly (no server, no auth). Builds search and detail requests, decodes positional-array responses into `Listing` objects via `decodeSearch` and `decodeItem`. Queries Craigslist's undocumented sapi endpoint. For "best deals" sort, routes through the worker instead. Pins its decoder logic to `worker/fixtures/search.json` so it never drifts from `worker/decode.js` silently. HTML bodies get collapsed to plain text by `sanitize()` before rendering. |
| `worker/decode.js` | Mirrors `CraigslistAPI.swift`'s decoding logic. Turns sapi's positional arrays into real objects. Exported as `decodeItem` and `decodeSearch`. Shares the same `worker/fixtures/search.json` fixture with the Swift implementation. Called by `worker.js` to build responses. |
| `worker/worker.js` | Cloudflare Worker entry point for web + KMP. Resolves city names to Craigslist area IDs via `areaId()` (seed from bundled `data/areas.json`, cache in Workers KV after first lookup). Forwards search requests to sapi with `rankByDeal()` if sort=deal. Calls `addDealReasons()` to attach Workers AI reasoning to the top 5 results. Returns JSON keyed by `POST /api/search` or `GET /search/full`. Five-minute cache on search responses. CORS headers set to allow any origin. |
| `worker/fixtures/`, `data/areas.json` + `worker/` | Shared fixtures and seed data. `areas.json` is the bundled city-to-area-id mapping, never changes, checked in to both locations. `worker/fixtures/search.json` is the single decoder test fixture, checked in once, used by both `CraigslistAPI` unit tests (Swift) and `worker/decode.test.mjs` (JavaScript) to prove they never diverge. |

## iOS / macOS

| File | What it owns |
|---|---|
| `Sources/iOS/CurbfindApp.swift` + `Sources/macOS/CurbfindMacApp.swift` | Entry points. Sets up a `Favorites` environment object for persistence across navigation. iOS: TabView with "Browse" (search) and "Saved" tabs. macOS: single window with the same two tabs. |
| `Sources/Views/ResultsList.swift` | Reusable results grid for both browse and saved tabs. Calls `model.run()` on task load. Formats each result as a row thumbnail, price, title, location. Links to `ListingDetailView`. Filters by `savedOnly` parameter. |
| `Sources/Views/ListingRow.swift` | Single result row: thumbnail, price badge, title, location, posted date. Tap navigates to detail. |
| `Sources/Views/ListingDetailView.swift` | Full listing detail. Carousel of images, title, price, posting date, location with map pin, listing attributes (bedrooms, etc.), full body text (plain text from `CraigslistAPI.sanitize`), "Open in Craigslist" link, save/unsave button. |
| `Sources/Views/FiltersView.swift` | Modal sheet for search filters. Pickers for category and sort. Text fields for price range, postal code, search distance. Toggle for photos only. Applies filters to the `SearchModel` on close. |
| `Sources/Models/Listing.swift` | Value types for a single listing and its detail page. `Listing`: id, uuid, title, slug, price, location, coordinates, images. `PostingDetail`: title, body (sanitized), price, location, attributes, image URLs. Computed properties derive thumbnail and detail URLs. |
| `Sources/Models/Favorites.swift` | In-memory Set backed by UserDefaults, keyed by listing uuid. `isSaved()`, `add()`, `remove()` methods. Persists on every change. `@Observable` for reactive updates. |
| `Sources/Models/Cities.swift` | Array of major cities hardcoded for the city picker. Used to seed the UI; the app accepts any city name and resolves it at search time via `AreaDirectory.id()`. |
| `Package.swift` | Root SPM manifest. Declares iOS and macOS targets. TUI executable target reuses the same `Models` source directory, no duplication. |
| `Tests/CraigslistAPITests.swift` | Unit tests for `decodeSearch` and `decodeItem` against the shared `worker/fixtures/search.json` fixture, ensures the Swift decoder never drifts from the JavaScript one. |

## Web

| File | What it owns |
|---|---|
| `web/index.html` | Landing page, also the app itself: a hero, search form, and results grid. Embedded device frame matching the visitor's user agent (iPhone/Android/Mac window). `onboarding.js` drives the interactive app inside. The worker endpoint is `/api/search`. |
| `web/onboarding.js` | Search form logic: text input, category/sort/filter pickers. Calls `fetch(/api/search?...)` and renders results. Clicking a result navigates to the detail page (Craigslist's own `/view/d/` URL). |
| `web/sw.js` | Service worker. Installed but not strictly needed (the worker's own cache-control header handles persistence). Left in place for future local-first enhancements. |
| `docs/index.html` | Landing page wrapper with device frame injection. Embeds the live app inside an iPhone/Android/Mac window frame. One click zooms to full screen. |
| `docs/devices.css` + `docs/tokens.css` | Styling for the device frames and app UI. Light theme with the Curbfind brand colors. |

## TUI

| File | What it owns |
|---|---|
| `tui/main.swift` | Command-line tool. Argument 1 is the search query, argument 2 is the city. Creates a `CraigslistAPI` instance and calls `search()`. Prints results as columns: price, title, location, date. Reads `CraigslistAPI` and `Listing` directly from `Sources/Models/` with no duplication. No sort or filter UI, just raw results. |

## Kotlin Multiplatform

| File | What it owns |
|---|---|
| `kmp/shared/src/commonMain/kotlin/com/nulljosh/curbside/CurbsideClient.kt` | Shared Kotlin code over both Android and desktop. Mirrors `CraigslistAPI.search()` logic: calls the worker's `/api/search` endpoint via HTTP, decodes the response, returns `Listing` objects. |
| `kmp/composeApp/src/androidMain/kotlin/com/nulljosh/curbside/MainActivity.kt` | Android entry point. Boots the Compose app. |
| `kmp/composeApp/src/commonMain/kotlin/com/nulljosh/curbside/SearchScreen.kt` | Shared search UI built with Compose Multiplatform. Search form, results grid, filters, detail view. Calls `CurbsideClient` to fetch results. |
| `kmp/composeApp/src/desktopMain/kotlin/com/nulljosh/curbside/Main.kt` | Desktop (JVM) entry point. Boots the Compose app. |
| `kmp/shared/src/androidMain/kotlin/` + `kmp/shared/src/jvmMain/kotlin/` | Platform-specific overrides. `CurrentTime` implementation for Android and desktop. |

## Build scripts and tests

| File | What it owns |
|---|---|
| `worker/decode.test.mjs` + `worker/worker.test.mjs` + `worker/deal.test.mjs` | JavaScript test suites for the worker. `decode.test.mjs` verifies `decodeSearch` and `decodeItem` against `worker/fixtures/search.json`. `deal.test.mjs` tests `rankByDeal()` and `addDealReasons()` against varied price/title inputs. `worker.test.mjs` integration tests the full worker. Run with `node --test`. |
| `scripts/build-site.sh` | Build script for the web landing page. Inlines the Curbfind app into the device frame HTML. |
| `scripts/fetch-cities.mjs` | Scrapes major city names from Craigslist and generates `data/areas.json` seed. Run periodically to keep the city list fresh. |
| `docs/privacy.html` | Privacy policy served at `/privacy`. |

## External services

- **Craigslist sapi:** `https://sapi.craigslist.org/web/v8/postings`. Undocumented. Ignores User-Agent. No auth. Returns JSON with positional-array encoding. Page size is fixed at 360 (any other size is rejected upstream). `cc` parameter is ignored (a Canadian city returns results fine with cc=US).
- **Cloudflare Worker:** Proxies sapi for CORS, applies deal ranking and AI reasoning, caches for five minutes. Bound to Workers KV for area ID caching and Workers AI for deal reasons.

## Gotchas

- **sapi positional arrays:** Array order changes between endpoints and no schema doc exists. Order is verified against Craigslist's own JS, not reverse-engineered. `Sources/Models/CraigslistAPI.swift` and `worker/decode.js` comment the indices.
- **URL construction:** Hand-built `<city>.craigslist.org/.../<id>.html` URLs 404. Always use the `url` field returned by the API (`/view/d/` shape).
- **HTML bodies:** Posting bodies are HTML written by strangers. Both `CraigslistAPI.sanitize()` and `worker/decode.js`'s `sanitizeBody()` collapse to plain text (no markup rendering) before display. Deliberately not a general HTML sanitizer.
- **AI deal reasons:** Workers AI is best-effort. A missing or misbehaving model fails silently (deal ranking alone still works). Model names rotate without much warning; `worker/addDealReasons()` logs errors to `wrangler tail`.
- **Prompt injection:** Titles go straight into the AI prompt. Reasons are only ever attached by an id the worker sent and already knows about, so the worst a hostile title can do is waste the model's output on a useless reason.
