// Craigslist publishes no city API, but /about/sites is a plain list of every
// site worldwide. Parse it once at build time so nothing scrapes at runtime.
import { writeFileSync } from "node:fs";

const html = await (await fetch("https://www.craigslist.org/about/sites")).text();
const cities = [...html.matchAll(/href="https:\/\/www\.craigslist\.org\/area\/([a-z0-9-]+)"[^>]*>([^<]+)</g)]
  .map(([, slug, name]) => ({ slug, name: name.trim() }));

const seen = new Set();
const uniq = cities.filter((c) => !seen.has(c.slug) && seen.add(c.slug));
uniq.sort((a, b) => a.name.localeCompare(b.name));

writeFileSync(new URL("../data/cities.json", import.meta.url), JSON.stringify(uniq));
console.log(`${uniq.length} cities`);
