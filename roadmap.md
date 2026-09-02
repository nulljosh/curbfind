# Curbside roadmap

Classifieds browser over Craigslist's undocumented JSON API.
Plan: `~/.claude/plans/magical-noodling-candy.md`.

## Open
- [x] (2026-09-02: synchronous localStorage read on load + write on toggle; Mac app built, launched, quit clean) Confirm favourites persist across a reload in a browser. Search, detail,
      photos, sanitised bodies and outbound links all working in Chrome;
      starring a listing is the one path never exercised.
- [ ] ~~App icon~~ (done 2026-09-02, price tag on dark, both targets), `architecture.svg`, `metadata/`, `.asc/workflow.json`.
- [ ] Run `asc-name-creator` to confirm the App Store name before submitting.
- [x] (2026-09-02) Launch the Mac app once to prove the native-direct path end to end.
- [ ] Decide on watchOS/visionOS. Deliberately skipped for now: a 360-result
      photo grid has no watch story and no visionOS-specific affordance.

## Notes
- Live at curbside.heyitsmejosh.com. Serve and share that, never the pages.dev URL.
- `sapi` ignores User-Agent completely, so native needs no disguise and no server.
- `cc` is ignored upstream; any page size but 360 is rejected.
- Posting bodies are stranger-authored HTML. Both decoders strip them to plain
  text; nothing may ever render them as markup.
- Craigslist does **not** block Cloudflare egress, verified against the live
  deployed Worker.
- Nothing ships under Craigslist's name. They hold the mark and have sued
  third-party clients before.
