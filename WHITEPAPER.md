# Curbside Technical Whitepaper

**v1.0.0** | September 2026

Curbside is a fast, clean browser for Craigslist classifieds: pick a city,
search, read the posting, save favourites. Web app plus native SwiftUI iOS and
macOS apps. Live at
[curbside.heyitsmejosh.com](https://curbside.heyitsmejosh.com).

## The data source

Craigslist publishes no API, but its own site fetches search results from an
undocumented JSON endpoint, `sapi.craigslist.org/web/v8/postings`. Curbside
reads that endpoint directly. Two upstream quirks shape the design:

- The endpoint needs a numeric **area id**, and Craigslist publishes no area
  directory. The Worker reads the id off a city's search page once (regex on
  `"areaId":N`), stores it in KV forever, and ships a seed of common cities in
  `data/areas.json`.
- It ignores `cc` and rejects any page size but 360, so neither is a
  parameter.

Responses are a compact positional encoding, not objects. `worker/decode.js`
turns them into `{ id, title, price, location, image, url }` records, and
`decode.test.mjs` pins the decoder against captured fixtures so an upstream
format change fails loudly.

## Two paths, one decoder

| Client | Path |
|---|---|
| Web | Cloudflare Worker at `/api` proxies `sapi`, decodes, caches 5 min, adds CORS |
| iOS / macOS | Call `sapi` directly; `sapi` ignores User-Agent, so no disguise and no server |

The Swift decoder in `Sources/Models` mirrors `decode.js`. Posting bodies are
stranger-authored HTML; both decoders strip them to plain text before display.

## Storage

Favourites live in `localStorage` on the web and `UserDefaults` natively.
Nothing is sent anywhere. The Worker holds only area ids.

## Naming

Nothing ships under Craigslist's name. They hold the mark and enforce it.

## License

MIT 2026, Joshua Trommel
