import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { decodeSearch, decodeItem } from "./decode.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/search.json", import.meta.url)));
const { items, total } = decodeSearch(fixture);

test("decodes every item without holes", () => {
  assert.ok(items.length > 100);
  assert.equal(total, fixture.data.totalResultCount);
  for (const i of items) {
    assert.equal(typeof i.title, "string");
    assert.match(String(i.id), /^\d{10}$/);       // offsets rebuild a real posting id
    assert.match(i.uuid, /^[A-Za-z0-9]{20,}$/);   // tag 13, not a positional slot
    assert.ok(i.postedDate > 1_700_000_000 && i.postedDate < 2_000_000_000);
    assert.ok(i.url.startsWith("https://www.craigslist.org/view/d/"));
  }
});

test("first item matches the live values it was captured with", () => {
  const a = items[0];
  assert.equal(a.id, 7957784777);
  assert.equal(a.uuid, "81sCtMbL4Q6jLnxcjZQ4Qm");
  assert.equal(a.price, 70);
  assert.equal(a.priceString, "$70");
  assert.equal(a.location, "Vancouver");
  assert.equal(a.postedDate, 1788122239);
  assert.equal(a.thumb, "https://images.craigslist.org/00J0J_jCrtEigzgOj_0CI0t2_300x300.jpg");
  assert.equal(a.images.length, 3);
});

test("free postings have no price, not -1", () => {
  const free = items.find((i) => i.priceString === "free");
  assert.equal(free.price, null);
});

import { sanitizeBody } from "./decode.js";

test("sanitizeBody strips markup and keeps line structure", () => {
  assert.equal(sanitizeBody("a<br>\nb"), "a\nb");
  assert.equal(sanitizeBody("<p>one</p><p>two</p>"), "one\n\ntwo");
  assert.equal(sanitizeBody("Tom &amp; Jerry &quot;hi&quot;"), 'Tom & Jerry "hi"');
  assert.equal(sanitizeBody(null), "");
});

test("sanitizeBody defuses a hostile posting body", () => {
  const hostile = `<img src=x onerror="alert(1)"><script>steal()</script>call me`;
  const out = sanitizeBody(hostile);
  assert.ok(!out.includes("<"), out);
  assert.ok(!out.includes("onerror"), out);
  assert.ok(out.endsWith("call me"));
});

test("the real fixture body survives sanitising as readable text", () => {
  const body = "Sleek desk<br>\nWidth: 120 cm<br>\nPrice: $70\n";
  assert.equal(sanitizeBody(body), "Sleek desk\nWidth: 120 cm\nPrice: $70");
});

// Edge cases: a well-formed but empty or partial response must decode to
// empty/null fields, never throw -- this is what stands between a bad
// upstream payload and a 500 the client can't recover from.

test("decodeSearch on zero results returns an empty list, not a throw", () => {
  const empty = { data: { items: [], totalResultCount: 0, location: { city: "nowhere" }, decode: fixture.data.decode } };
  const result = decodeSearch(empty);
  assert.deepEqual(result.items, []);
  assert.equal(result.total, 0);
});

test("decodeItem with no tagged arrays at all still returns a shell object", () => {
  // [idOff, dateOff, categoryId, price, geo, shortCode, title] -- nothing between [6] and the title
  const item = [1, 1, "sss", -1, "0:0~0~0", "abc", "Untitled"];
  const out = decodeItem(item, { minPostingId: 1000, minPostedDate: 1_700_000_000, locationDescriptions: ["Nowhere"] });
  assert.equal(out.uuid, null);
  assert.equal(out.slug, null);
  assert.equal(out.priceString, null);
  assert.deepEqual(out.images, []);
  assert.equal(out.thumb, null);
  assert.equal(out.url, null, "no uuid or slug means no canonical URL, not a broken one");
  assert.equal(out.price, null, "-1 is craigslist's sentinel for no price");
});

test("decodeItem with a non-string geo field leaves location and coordinates null", () => {
  const item = [1, 1, "sss", 5, null, "abc", [13, "uuid123"], "Title"];
  const out = decodeItem(item, { minPostingId: 1000, minPostedDate: 1_700_000_000, locationDescriptions: [] });
  assert.equal(out.location, null);
  assert.equal(out.lat, null);
  assert.equal(out.lon, null);
});

test("decodeItem with an out-of-range location index falls back to null rather than throwing", () => {
  const item = [1, 1, "sss", 5, "0:99~49.28~-123.12", "abc", [13, "uuid123"], "Title"];
  const out = decodeItem(item, { minPostingId: 1000, minPostedDate: 1_700_000_000, locationDescriptions: ["Only one entry"] });
  assert.equal(out.location, null);
  assert.equal(out.lat, 49.28);
  assert.equal(out.lon, -123.12);
});

test("sanitizeBody on non-string-shaped falsy input never throws", () => {
  assert.equal(sanitizeBody(undefined), "");
  assert.equal(sanitizeBody(""), "");
  assert.equal(sanitizeBody(0), "");
});
