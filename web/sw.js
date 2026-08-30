// ponytail: cache the shell only. Listings go stale in minutes, so caching them
// would be worse than not having them.
const SHELL = ["./", "./index.html", "./tokens.css", "./cities.json"];
self.addEventListener("install", (e) => {
  e.waitUntil(caches.open("curbside-v1").then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;
  e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
