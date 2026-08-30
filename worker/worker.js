import { decodeSearch } from "./decode.js";

const SAPI = "https://sapi.craigslist.org/web/v8/postings";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36";
// ponytail: sapi ignores cc (a CA area answers fine with cc=US) and rejects any
// page size but 360, so neither is worth a parameter.
const PAGE = 360;

// Craigslist publishes no area directory, so read the id off the city's own
// search page once and keep it forever -- these never change.
async function areaId(city, env) {
  const key = `area:${city}`;
  const hit = await env.AREAS.get(key);
  if (hit) return Number(hit);
  const res = await fetch(`https://www.craigslist.org/search/area/${encodeURIComponent(city)}`, {
    headers: { "User-Agent": UA },
  });
  const id = (await res.text()).match(/"areaId":(\d+)/)?.[1];
  if (!id) return null;
  await env.AREAS.put(key, id);
  return Number(id);
}

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "cache-control": "public, max-age=300",
    },
  });

async function search(url, env) {
  const p = url.searchParams;
  const city = p.get("city") || "vancouver";
  const id = await areaId(city, env);
  if (!id) return json({ error: `unknown city "${city}"` }, 404);

  const offset = Math.max(0, Number(p.get("offset")) || 0);
  const q = new URLSearchParams({
    batch: `${id}-${offset}-${PAGE}-0-0`,
    cc: "US",
    lang: "en",
    searchPath: p.get("cat") || "sss",
  });
  if (p.get("q")) q.set("query", p.get("q"));
  // Remaining filters are Craigslist's own and pass straight through.
  for (const k of ["min_price", "max_price", "postal", "search_distance", "hasPic", "sort", "srchType"]) {
    if (p.get(k)) q.set(k, p.get(k));
  }

  const res = await fetch(`${SAPI}/search/full?${q}`, { headers: { "User-Agent": UA } });
  if (!res.ok) return json({ error: "upstream refused the search" }, 502);
  const payload = await res.json();
  if (payload.errors?.length) return json({ error: payload.errors[0].message }, 502);
  return json({ ...decodeSearch(payload), city, offset });
}

async function post(uuid) {
  const res = await fetch(`${SAPI}/${encodeURIComponent(uuid)}?cc=US&lang=en`, {
    headers: { "User-Agent": UA },
  });
  const payload = await res.json();
  const item = payload.data?.items?.[0];
  if (!item) return json({ error: payload.errors?.[0]?.message || "not found" }, 404);
  return json({
    ...item,
    images: (item.images || []).map((t) => `https://images.craigslist.org/${t.replace(/^\d+:/, "")}_600x450.jpg`),
  });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const ip = req.headers.get("cf-connecting-ip") || "anon";
    const { success } = await env.RATE_LIMITER.limit({ key: ip });
    if (!success) return json({ error: "slow down" }, 429);

    if (url.pathname === "/api/search") return search(url, env);
    const uuid = url.pathname.match(/^\/api\/post\/([\w-]+)$/)?.[1];
    if (uuid) return post(uuid);
    return json({ error: "not found" }, 404);
  },
};
