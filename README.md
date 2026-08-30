# Curbside

A faster way to browse local classifieds. Web, iOS and macOS.

| Platform | Status | Talks to |
|---|---|---|
| Web | live — https://curbside-3v2.pages.dev | Cloudflare Worker (CORS leaves no choice) |
| iOS | builds | Craigslist directly, no server |
| macOS | builds | Craigslist directly, no server |

## How it works

Craigslist blocks scraped HTML and RSS, but its own site runs on an undocumented
JSON API at `sapi.craigslist.org` that takes no auth, sets no cookies and ignores
User-Agent entirely. The native apps call it straight from `URLSession`. Only the
web app needs the Worker, because browsers enforce CORS and the API sends no
CORS headers.

Search results come back as bare positional arrays against a per-response
dictionary. `worker/decode.js` and `Sources/Models/CraigslistAPI.swift` are two
ports of the same decoder, both pinned by `worker/fixtures/search.json` so they
cannot drift apart silently.

## Build

```sh
cd worker && node --test        # decoder + sanitiser  (not from the repo root)
./scripts/build-site.sh         # docs -> /, web -> /app
npx wrangler deploy --config worker/wrangler.jsonc
xcodegen && xcodebuild -scheme Curbside -destination 'platform=macOS' build
```

`scripts/fetch-cities.mjs` regenerates `data/cities.json` from Craigslist's
public site list. `data/areas.json` seeds 41 area ids; the rest resolve lazily
and cache (KV on the Worker, `UserDefaults` on native).

## Not affiliated with craigslist

Curbside reads public listings and links every reply back to the original
posting. It is not affiliated with, endorsed by, or connected to craigslist, and
carries none of their branding.
