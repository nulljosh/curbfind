# Curbfind Technical Whitepaper

**v1.0.0** | September 2026

Craigslist's own site is slow, cluttered with ads, and hard to scan on a
phone. Curbfind exists because the listings are good and the interface
around them isn't: pick a city, search, read the posting, save favourites,
nothing else. Web app plus native SwiftUI iOS and macOS apps. Live at
[curbfind.heyitsmejosh.com](https://curbfind.heyitsmejosh.com).

## The data source

Craigslist publishes no API, but its own site fetches search results from an
undocumented JSON endpoint, `sapi.craigslist.org/web/v8/postings`. Curbfind
reads that endpoint directly rather than scraping HTML, because HTML changes
its markup far more often than a JSON contract changes its shape. Two
upstream quirks shape the design:

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

Native apps skip the Worker because they don't need it: no browser CORS
restriction, no reason to pay for a hop that only exists to route around a
browser limitation. The Swift decoder in `Sources/Models` mirrors `decode.js`
by hand rather than sharing code across languages, and both are pinned to
the same fixture so a silent drift between them fails a test instead of
shipping. Posting bodies are stranger-authored HTML; both decoders strip
them to plain text before display, because rendering a stranger's markup is
a security surface, not a formatting nicety.

## Storage

Favourites live in `localStorage` on the web and `UserDefaults` natively.
Nothing is sent anywhere, because a list of saved postings isn't Curbfind's
data to collect: there's no account, so no server has anywhere to put it
even if it wanted to. The Worker holds only area ids.

## Naming

Nothing ships under Craigslist's name. They hold the mark and enforce it.

## License

MIT 2026, Joshua Trommel
