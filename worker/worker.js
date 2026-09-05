import { decodeSearch, sanitizeBody } from "./decode.js";
import SEED from "../data/areas.json" with { type: "json" };

const SAPI = "https://sapi.craigslist.org/web/v8/postings";
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36";
// ponytail: sapi ignores cc (a CA area answers fine with cc=US) and rejects any
// page size but 360, so neither is worth a parameter.
const PAGE = 360;

// Craigslist publishes no area directory, so read the id off the city's own
// search page once and keep it forever -- these never change.
async function areaId(city, env) {
  if (SEED[city]) return SEED[city];
  const key = `area:${city}`;
  const hit = await env.AREAS.get(key);
  if (hit) return Number(hit);
  const res = await fetch(`https://www.craigslist.org/search/area/${encodeURIComponent(city)}`, {
    headers: { "User-Agent": UA },
  });
  if (!res.ok) return null; // craigslist 404s cleanly on an unknown slug
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

// ponytail: no market-price API exists, so "deal" is relative to the other
// results in this same search -- cheaper than the batch median, ranked first.
// Items are attacker-controlled JSON from decodeSearch; price is either a
// finite number or null (decodeSearch maps craigslist's -1 sentinel to null),
// never NaN/Infinity, so no further validation is needed here.
export function rankByDeal(items) {
  const priced = items.map((i) => i.price).filter((p) => p != null).sort((a, b) => a - b);
  if (!priced.length) return items;
  const median = priced[Math.floor(priced.length / 2)];
  const scored = items.map((i) => ({
    ...i,
    dealScore: i.price == null ? -Infinity : (median - i.price) / median,
  }));
  scored.sort((a, b) => b.dealScore - a.dealScore);
  return scored;
}

const MAX_REASON_LEN = 80;

// One batched call covers the whole page instead of one call per listing.
// Best-effort: a slow, failing, or misbehaving model just means no reasons,
// never a broken search -- deal ranking above already stands on its own.
export async function addDealReasons(items, env) {
  const top = items.slice(0, 5).filter((i) => i.price != null);
  if (!top.length || !env.AI) return items;
  const ids = new Set(top.map((i) => String(i.id)));
  // Titles are written by strangers and go straight into the prompt: this is
  // a live prompt-injection surface. Nothing here trusts the model back --
  // its reply is only ever used as a display string keyed by an id we
  // already know about, matched against ids we sent, so the worst a hostile
  // title can do is waste the model's own output on a useless reason.
  const list = top.map((i) => `${i.id}: "${i.title.slice(0, 200).replace(/"/g, "'")}" - ${i.priceString}`).join("\n");
  try {
    const res = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
      messages: [{
        role: "user",
        content: `These are classifieds listings, cheapest-relative-to-market first. In one short punchy phrase each (under 8 words), say why it looks like a good deal. Reply as JSON only, no other text: {"id": "reason"}.\n\n${list}`,
      }],
    });
    const parsed = JSON.parse(String(res?.response ?? "").match(/\{[\s\S]*\}/)?.[0] || "{}");
    if (!parsed || typeof parsed !== "object") return items;
    const reasons = {};
    for (const [id, reason] of Object.entries(parsed)) {
      if (ids.has(id) && typeof reason === "string" && reason.trim()) {
        reasons[id] = reason.trim().slice(0, MAX_REASON_LEN);
      }
    }
    return items.map((i) => (reasons[i.id] ? { ...i, dealReason: reasons[i.id] } : i));
  } catch {
    return items; // ponytail: AI is a garnish here, not load-bearing
  }
}

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
  const dealSort = p.get("sort") === "deal";
  // Remaining filters are Craigslist's own and pass straight through.
  // "deal" isn't a Craigslist sort -- we rank locally, so don't forward it.
  for (const k of ["min_price", "max_price", "postal", "search_distance", "hasPic", "sort", "srchType"]) {
    if (p.get(k) && !(k === "sort" && dealSort)) q.set(k, p.get(k));
  }

  const res = await fetch(`${SAPI}/search/full?${q}`, { headers: { "User-Agent": UA } });
  if (!res.ok) return json({ error: "upstream refused the search" }, 502);
  const payload = await res.json();
  if (payload.errors?.length) return json({ error: payload.errors[0].message }, 502);
  const decoded = decodeSearch(payload);
  const items = dealSort ? await addDealReasons(rankByDeal(decoded.items), env) : decoded.items;
  return json({ ...decoded, items, city, offset });
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
    // Never ship the raw HTML onward -- see sanitizeBody in decode.js.
    body: sanitizeBody(item.body),
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
