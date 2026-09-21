**Post 1:**
Craigslist has the best local listings on the internet and the worst interface for finding them. Built Curbfind to fix that: one photo grid, any of 700 cities, search and save. Free, no account. https://curbfind.heyitsmejosh.com

**Post 2:**
iOS and Mac talk to Craigslist's own search endpoint directly, no server in between. Web needs a small Cloudflare Worker just to get around one browser CORS rule. Same decoder, same test fixture, both sides.

**Post 3:**
Also has a "best deals" sort: ranks listings against the median price of that same search and tags a few with a one-line reason why. No account, no tracking, favourites stay on your device. Free on web, iOS, macOS, Android and desktop.
