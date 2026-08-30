# Curbside roadmap

Classifieds browser over Craigslist's undocumented JSON API.
Plan: `~/.claude/plans/magical-noodling-candy.md`.

## Open
- [ ] Confirm the web app renders and searches in a real browser — the API is
      verified by curl, the UI has never been looked at.
- [ ] App icon, `architecture.svg`, `metadata/`, `.asc/workflow.json`.
- [ ] Run `asc-name-creator` to confirm the App Store name before submitting.
- [ ] Launch the Mac app once to prove the native-direct path end to end.
- [ ] Custom domain instead of the pages.dev URL.
- [ ] Decide on watchOS/visionOS. Deliberately skipped for now: a 360-result
      photo grid has no watch story and no visionOS-specific affordance.

## Notes
- `sapi` ignores User-Agent completely, so native needs no disguise and no server.
- `cc` is ignored upstream; any page size but 360 is rejected.
- Posting bodies are stranger-authored HTML. Both decoders strip them to plain
  text; nothing may ever render them as markup.
- Craigslist does **not** block Cloudflare egress — verified against the live
  deployed Worker.
- Nothing ships under Craigslist's name. They hold the mark and have sued
  third-party clients before.
