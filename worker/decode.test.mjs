import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { decodeSearch } from "./decode.js";

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
