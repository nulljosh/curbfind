# Curbfind roadmap

Classifieds browser over Craigslist's undocumented JSON API.
Plan: `~/.claude/plans/magical-noodling-candy.md`.

## Open
- [ ] ~~App icon~~ (done 2026-09-05, location pin on dark — city search is the core action), `architecture.svg`, `metadata/`, `.asc/workflow.json`.
- [ ] Run `asc-name-creator` to confirm the App Store name before submitting.
      2026-09-03: public search shows no exact "Curbfind" match but many close
      variants exist (Curbfind Waste, Curbfind Health, etc) — exact-match ASC
      probe still needed, not done. iOS target already builds clean, so this
      app is closer to submit-ready than Roost.
- [ ] OfferUp reviews complain about off-platform scam redirects and bans with
      no recourse. Curbfind (browser, no payments) sidesteps that class of
      complaint entirely — worth a line in store copy once listed.
- [ ] Decide on watchOS/visionOS. Deliberately skipped for now: a 360-result
      photo grid has no watch story and no visionOS-specific affordance.

## Notes
- Live at curbfind.heyitsmejosh.com. Serve and share that, never the pages.dev URL.
- `sapi` ignores User-Agent completely, so native needs no disguise and no server.
- `cc` is ignored upstream; any page size but 360 is rejected.
- Posting bodies are stranger-authored HTML. Both decoders strip them to plain
  text; nothing may ever render them as markup.
- Craigslist does **not** block Cloudflare egress, verified against the live
  deployed Worker.
- Nothing ships under Craigslist's name. They hold the mark and have sued
  third-party clients before.

## TUI pilot (2026-09-05)
- `curbside-tui` SwiftPM target (SwiftTUI). `swift build && ./.build/debug/curbside-tui "bike" vancouver` reuses CraigslistAPI.swift as-is, same client the native apps use. Needs a real TTY.
- [x] architecture.svg missing — sibling apps have one, this doesn't (project-sync 2026-09-05)
