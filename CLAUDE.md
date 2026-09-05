# Curbfind

Craigslist browser, no clutter: search, read, save. Web + native SwiftUI iOS/macOS + Kotlin Multiplatform Android/desktop. Live at [curbfind.heyitsmejosh.com](https://curbfind.heyitsmejosh.com). ASC 6809031662 (renamed from curbside 2026-09-05, Pages project is still `curbside`).

## Stack
- `worker/`: Cloudflare Worker (`curbside-api`), talks to Craigslist's own undocumented `sapi.craigslist.org/web/v8/postings` endpoint. `decode.js` turns its positional-array responses into real objects. KV caches city → area id forever (Craigslist publishes no directory). Native rate limiting via the `ratelimit` binding.
- `web/`: static HTML/JS, calls the worker for CORS reasons.
- `Sources/`: SwiftUI, iOS 17+/macOS 14+. `CraigslistAPI.swift` talks to Craigslist's sapi **directly** — no server in that path — because native apps have no CORS restriction. It's a hand-port of `worker/decode.js`, pinned to the same `worker/fixtures/search.json` fixture so the two can't drift apart silently.
- `kmp/`: Kotlin Multiplatform (Android + desktop Compose), goes through the worker's JSON endpoint like the web app.
- `tui/`: SwiftPM executable reusing `Sources/Models/CraigslistAPI.swift` and `Listing.swift` directly (see root `Package.swift`), no sort/filter UI.

## The one exception: AI deal ranking
"Best deals" sort is the only thing that isn't Craigslist-direct on native. No market-price API exists, so a deal is scored relative to the median price of the same search's own results (`rankByDeal` in `worker/worker.js`), then Workers AI (`@cf/meta/llama-3.1-8b-instruct-fp8`) tags the top 5 with a one-line reason (`addDealReasons`). Because only the worker has the AI binding, **all four platforms route this one sort through it** — iOS/macOS and Android/desktop otherwise never touch the worker for search.

Two things bit us in production, both fixed and covered in `worker/deal.test.mjs`:
- Cloudflare deprecates Workers AI model names without much warning; `addDealReasons` swallows AI failures by design (never breaks the search), which also means a bad model name fails *silently* — `console.error` on that path now, check `wrangler tail` if reasons go missing again.
- The model ignores the requested flat `{"id":"reason"}` schema about as often as it follows it, replying with an array of `{id, reason}` objects instead. The parser accepts both shapes; don't assume compliance if you touch this again.

Listing titles are untrusted and go straight into the AI prompt — a live prompt-injection surface. A reason is only ever attached by an id the worker itself sent and already knows about, type-checked as a string, length-capped at 80 chars. Worst case a hostile title wastes the model's own output on a useless reason.

## Gotchas
- `sapi` ignores `cc` (a Canadian area answers fine with `cc=US`) and rejects any page size but 360.
- Hand-built `<city>.craigslist.org/.../<id>.html` URLs 404. Always use the `url` field the API gives back (`/view/d/<slug>/<uuid>`).
- Posting bodies are HTML written by strangers; `sanitizeBody`/`Self.sanitize` collapse to plain text before anything renders them, deliberately not a markup sanitizer.
- A push deploys nothing here either. Worker: `wrangler deploy` from `worker/`. Web: `wrangler pages deploy web --project-name curbside`.

## Open work
See `roadmap.md`.
