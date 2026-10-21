# Curbfind roadmap

> Priority tier 1 (2026-10-17): live blocker, work first. Order: live blockers, ship pushes, active features, portfolio, exploratory. See ~/Documents/Code/LOOP-HANDOFF.md.

Classifieds browser over Craigslist's undocumented JSON API.
Plan: `~/.claude/plans/magical-noodling-candy.md`.

## Open
- [ ] ~~App icon~~ (done 2026-09-05, location pin on dark — city search is the core action), `architecture.svg`, `metadata/`, `.asc/workflow.json`.
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

## Ingested 2026-10-05
- [ ] QA

## Ingested 2026-10-16
- [ ] Needs iOS ship (macOS live, iOS 1.0.0 waiting). (screenshot: notes/attachments/2026-10-16/app-store-releases-1.png)
  - 2026-10-21 check: iOS 1.0.0 is PREPARE_FOR_SUBMISSION with submission a5b53544 UNRESOLVED_ISSUES (rejected 2026-10-05 under 4.3 spam + 4.2.6; the nine-question reply went out 2026-10-05 18:00, no resubmit). Blocked on Joshua: `asc web auth login` (2FA) so `asc web review show --app 6809031662` can read whether Apple answered. Never resubmit unchanged; if Apple holds the line, it needs real new iOS-only features first.

## Ingested 2026-10-17
- [ ] Better name. (Clarify: rename candidates, .com only, single word.)
- [ ] QA.
