# Curbside roadmap

Classifieds browser over Craigslist's undocumented JSON API. Plan:
`~/.claude/plans/magical-noodling-candy.md`.

## Done (2026-08-30)
- Reverse-engineered `sapi.craigslist.org` end to end: search, detail, images,
  areaId resolution. All verified against live responses.
- `worker/decode.js` — turns positional search arrays into real objects.
- `worker/decode.test.mjs` + `fixtures/search.json` — 3 tests, passing. This is
  the tripwire if Craigslist reshuffles the array format.
- `worker/worker.js` + `wrangler.jsonc` — `/api/search`, `/api/post/{uuid}`.

## Next
- Create the KV namespace and fill `REPLACE_WITH_KV_ID` in `wrangler.jsonc`.
- Deploy the Worker. **Risk checkpoint:** if Craigslist blocks Cloudflare egress
  IPs the proxy 403s. Fallback is porting the decoder to Swift and letting native
  clients call sapi from the user's own IP.
- Phase 2: `web/index.html` PWA — city/category/query, results grid, detail
  overlay, favourites in localStorage. Portfolio `tokens.css`.
- Phase 3/4: iOS then macOS, xcodegen, mirroring `nimble`'s target split.
- Name check via `asc-name-creator` before any submission.

## Notes
- Nothing in the name, icon, or listing may reference Craigslist. They hold the
  mark and have sued third-party clients before. Every reply links out to
  craigslist.org.
- `sapi` ignores `cc` and rejects any page size but 360.
