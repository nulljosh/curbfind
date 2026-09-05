import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "./worker.js";

// worker.js hits the network (Craigslist's sapi, and its own area-lookup page)
// and reads two bindings (env.AREAS, env.RATE_LIMITER). These tests stub both
// so the HTTP-error-mapping logic -- the part that decides what the client
// sees when Craigslist errors out -- is exercised without a real network call.

function makeEnv({ rateLimited = false, areaId = 54321 } = {}) {
  return {
    AREAS: { get: async () => String(areaId), put: async () => {} },
    RATE_LIMITER: { limit: async () => ({ success: !rateLimited }) },
  };
}

function withFetch(impl, fn) {
  const real = globalThis.fetch;
  globalThis.fetch = impl;
  return fn().finally(() => { globalThis.fetch = real; });
}

test("unknown city returns 404 with an error message, not a crash", async () => {
  const env = { AREAS: { get: async () => null, put: async () => {} }, RATE_LIMITER: { limit: async () => ({ success: true }) } };
  await withFetch(async () => new Response("not found", { status: 404 }), async () => {
    const res = await worker.fetch(new Request("https://x/api/search?city=nowhereville"), env);
    assert.equal(res.status, 404);
    const body = await res.json();
    assert.match(body.error, /nowhereville/);
  });
});

test("upstream non-OK response surfaces as 502, never a raw 500", async () => {
  const env = makeEnv();
  await withFetch(async () => new Response("", { status: 503 }), async () => {
    const res = await worker.fetch(new Request("https://x/api/search?city=vancouver"), env);
    assert.equal(res.status, 502);
    const body = await res.json();
    assert.equal(body.error, "upstream refused the search");
  });
});

test("upstream error payload forwards Craigslist's own message", async () => {
  const env = makeEnv();
  await withFetch(async () => Response.json({ errors: [{ message: "bad details_length" }] }), async () => {
    const res = await worker.fetch(new Request("https://x/api/search?city=vancouver"), env);
    assert.equal(res.status, 502);
    const body = await res.json();
    assert.equal(body.error, "bad details_length");
  });
});

test("rate limiting returns 429 before any upstream call is made", async () => {
  const env = makeEnv({ rateLimited: true });
  let fetchCalled = false;
  await withFetch(async () => { fetchCalled = true; return new Response(""); }, async () => {
    const res = await worker.fetch(new Request("https://x/api/search?city=vancouver"), env);
    assert.equal(res.status, 429);
    assert.equal(fetchCalled, false, "a rate-limited request must short-circuit before touching the network");
  });
});

test("an unrecognized route returns 404, not a silent empty body", async () => {
  const env = makeEnv();
  const res = await worker.fetch(new Request("https://x/api/nonsense"), env);
  assert.equal(res.status, 404);
});

test("post lookup for a missing uuid returns 404 with craigslist's own error when present", async () => {
  const env = makeEnv();
  await withFetch(async () => Response.json({ errors: [{ message: "not found" }] }), async () => {
    const res = await worker.fetch(new Request("https://x/api/post/doesnotexist"), env);
    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.error, "not found");
  });
});
