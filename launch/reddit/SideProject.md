Subreddit: r/SideProject
Note: no karma/flair gate that I know of, ask Joshua before posting if unsure. Public, not beta-only.

Title: I got tired of Craigslist's UI so I rebuilt search around a photo grid

Body:

Craigslist's listings are still good. The site around them hasn't changed since 2003: a wall of blue text links, no photos until you click in. I built Curbfind to fix just that part.

It reads Craigslist's own undocumented search endpoint directly (not scraping HTML) and turns the response into a photo grid: image, price, title, place, all at once. Any of 700 cities, filter by price or distance, star what you're watching. There's also a "best deals" sort that ranks a listing against the median price of its own search results and has a small model tag a few standouts with a one-line reason.

iOS and macOS call Craigslist's endpoint straight from the device, no server involved, because native apps don't hit a browser's CORS wall. The web version needs a tiny Cloudflare Worker only to get around that one browser limit. No account anywhere, favourites stay in local storage/UserDefaults on your own device.

It's free on web, iOS, macOS, Android and desktop, no catch.

Would like feedback on the search UX and whether the deal-ranking sort is actually useful or just noise.

https://curbfind.heyitsmejosh.com
