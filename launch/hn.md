Skip: no technical hook

**Title (66 chars):** Show HN: Curbfind – Craigslist, without the 2003-era clutter

**Body:**

Craigslist's own site still runs on a wall of blue text links with no photos up front. The listings are good, the interface around them isn't, so I built Curbfind: pick a city, search, see a photo grid instead of a link list, save what you're watching. It reads Craigslist's own undocumented search endpoint directly rather than scraping HTML, decoded with a fixture-pinned parser so an upstream format change fails a test instead of shipping broken. iOS and macOS call that endpoint straight from the device, no server in the middle, since native apps don't hit a browser's CORS wall. There's a small Cloudflare Worker only for the web version to get around that one browser limit. No account, no tracking, favourites stay on your device. Free on web, iOS, macOS, Android and desktop. Would love feedback on the "best deals" sort, which ranks a listing against the median price of its own search results and has Workers AI tag a few with a one-line reason.

Web: https://curbfind.heyitsmejosh.com
Source: https://github.com/nulljosh/curbfind
