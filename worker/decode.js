// Craigslist's sapi returns search results as positional arrays against a
// per-response dictionary. This turns them into real objects.
//
//   [0] postingId offset from decode.minPostingId
//   [1] postedDate offset from decode.minPostedDate (unix seconds)
//   [2] categoryId
//   [3] numeric price, -1 = none
//   [4] "<locations idx>:<locationDescriptions idx>~lat~lon"
//   [5] short code
//   ...[tag, ...values] in any order: 4=images 6=slug 10=priceString 13=uuid
//   last = title

const IMG = (token) => `https://images.craigslist.org/${token.replace(/^\d+:/, "")}`;

export function decodeItem(item, decode) {
  const [idOff, dateOff, categoryId, price, geo] = item;
  const title = item[item.length - 1];

  let uuid = null, slug = null, priceString = null, images = [];
  for (const f of item.slice(6, -1)) {
    if (!Array.isArray(f)) continue;
    switch (f[0]) {
      case 4: images = f.slice(1); break;
      case 6: slug = f[1]; break;
      case 10: priceString = f[1]; break;
      case 13: uuid = f[1]; break;
    }
  }

  // The neighbourhood label is indexed from inside the geo string, not from a
  // slot of its own: "<locations idx>:<locationDescriptions idx>~lat~lon".
  const [idx, lat, lon] = typeof geo === "string" ? geo.split("~") : [];
  const descIdx = idx ? Number(idx.split(":")[1]) : NaN;

  return {
    id: decode.minPostingId + idOff,
    uuid,
    title,
    slug,
    price: price === -1 ? null : price,
    priceString,
    postedDate: decode.minPostedDate + dateOff,
    categoryId,
    location: decode.locationDescriptions[descIdx] || null,
    lat: lat ? Number(lat) : null,
    lon: lon ? Number(lon) : null,
    thumb: images[0] ? IMG(images[0]) + "_300x300.jpg" : null,
    images: images.map((t) => IMG(t) + "_600x450.jpg"),
    // ponytail: canonical /view/d/ URL, reconstructing the per-subarea
    // hostname URL 404s. Detail responses carry this same shape.
    url: uuid && slug ? `https://www.craigslist.org/view/d/${slug}/${uuid}` : null,
  };
}

export function decodeSearch(payload) {
  const d = payload.data;
  return {
    items: d.items.map((i) => decodeItem(i, d.decode)),
    total: d.totalResultCount,
    location: d.location,
  };
}

// Posting bodies are HTML written by strangers. Nothing downstream may render
// them as markup, so collapse to plain text here and let every client insert it
// as a text node. Deliberately not a general HTML sanitiser: an allowlist you
// have to keep correct is a liability, and Craigslist bodies are only ever
// paragraphs, breaks and links.
export function sanitizeBody(html) {
  if (!html) return "";
  return html
    .replace(/<br\s*\/?>\s*/gi, "\n")
    .replace(/<\/p>\s*/gi, "\n\n")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0*39;|&apos;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}
