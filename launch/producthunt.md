# Product Hunt draft, Curbfind

**Name:** Curbfind (9 chars)

**Tagline (57 chars):** Craigslist, without the 2003-era clutter

**Description (247 chars):**
Curbfind puts every Craigslist listing in one photo grid, across 700 cities. Search, filter by price or distance, save what you're watching. No account, no tracking, no ads. iOS, Mac, Android, desktop and web, all reading Craigslist directly.

**Topics:** Marketplace, Productivity, Open Source

**Pricing line:** Free.

**First comment (maker story):**

Craigslist still has the best local listings on the internet. Finding them is the problem: a wall of blue text links, no photos up front, an interface that hasn't moved since 2003. I wanted the listings without the site.

Curbfind reads Craigslist's own search endpoint directly and turns it into a photo grid: price, title, place, image, all at once. Pick any of 700 cities, filter by price or distance, star what you're watching. It also has a "best deals" sort that ranks listings against the median price of that same search and tags a few standouts with a one-line reason why.

The interesting part is what's not there. iOS and macOS talk to Craigslist's endpoint directly, no server in between, because native apps don't have a browser's CORS restriction. The web version needs a small Cloudflare Worker to get around that one browser limit, cached five minutes. Everything is decoded from the same fixture on both sides, so an upstream format change fails a test instead of shipping broken.

Favourites live in localStorage or UserDefaults. Nothing is sent anywhere. There's no account, so there's nowhere for that data to go even if I wanted it to.

Curbfind is free, full stop, on web, iOS, macOS, Android, and desktop. No subscription, no paywall, no ads. Nothing is held back behind a price today.

**Links:**
- Web: https://curbfind.heyitsmejosh.com
- App Store: https://apps.apple.com/app/id6809031662
- GitHub: https://github.com/nulljosh/curbfind
