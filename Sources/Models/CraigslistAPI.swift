import Foundation

/// Talks to Craigslist directly. There is no Curbside server in this path.
///
/// The API ignores User-Agent entirely (verified: a browser UA, curl's default,
/// a CFNetwork-shaped one and no UA header at all all return byte-identical
/// responses), takes no auth and sets no cookies, so URLSession needs no
/// disguise. Only the web app proxies, and only because CORS leaves it no choice.
///
/// This is a port of worker/decode.js. Both are pinned by the same
/// worker/fixtures/search.json so they cannot drift apart silently.
struct CraigslistAPI {
    enum Failure: LocalizedError {
        case unknownCity(String)
        case upstream(String)

        var errorDescription: String? {
            switch self {
            case .unknownCity(let c): return "No classifieds site called \"\(c)\"."
            case .upstream(let m): return m
            }
        }
    }

    struct SearchResults {
        let listings: [Listing]
        let total: Int
        let cityName: String?
    }

    /// Any page size but 360 is rejected upstream with `bad details_length`.
    private static let pageSize = 360
    private static let sapi = "https://sapi.craigslist.org/web/v8/postings"

    var session: URLSession = .shared
    var areas: AreaDirectory = .shared

    // MARK: - Search

    func search(_ f: SearchFilters, offset: Int = 0) async throws -> SearchResults {
        guard let area = try await areas.id(for: f.city, session: session) else {
            throw Failure.unknownCity(f.city)
        }

        var items = [URLQueryItem(name: "batch", value: "\(area)-\(offset)-\(Self.pageSize)-0-0"),
                     // cc is ignored upstream -- a Canadian area answers fine with US.
                     URLQueryItem(name: "cc", value: "US"),
                     URLQueryItem(name: "lang", value: "en"),
                     URLQueryItem(name: "searchPath", value: f.category)]
        if !f.query.isEmpty { items.append(.init(name: "query", value: f.query)) }
        if !f.minPrice.isEmpty { items.append(.init(name: "min_price", value: f.minPrice)) }
        if !f.maxPrice.isEmpty { items.append(.init(name: "max_price", value: f.maxPrice)) }
        if !f.postal.isEmpty { items.append(.init(name: "postal", value: f.postal)) }
        if !f.distance.isEmpty { items.append(.init(name: "search_distance", value: f.distance)) }
        if f.hasPhoto { items.append(.init(name: "hasPic", value: "1")) }
        if f.sort != "rel" { items.append(.init(name: "sort", value: f.sort)) }

        var comps = URLComponents(string: "\(Self.sapi)/search/full")!
        comps.queryItems = items

        let (data, _) = try await session.data(from: comps.url!)
        return try Self.decodeSearch(data)
    }

    // MARK: - Deal ranking (AI)
    //
    // The only path in this file that isn't a direct-to-Craigslist call: the
    // AI reasoning behind "Best deals" runs on Workers AI, which only the
    // curbside-api worker has a binding to. Everything else stays native.
    private static let workerAPI = "https://curbside-api.trommatic.workers.dev"

    private struct WorkerSearchResponse: Decodable {
        let items: [WorkerItem]
        let total: Int
        let location: Loc?
        struct Loc: Decodable { let city: String? }
    }

    private struct WorkerItem: Decodable {
        let id: Int, uuid: String?, title: String, slug: String?
        let price: Int?, priceString: String?, postedDate: Double
        let location: String?, lat: Double?, lon: Double?
        let images: [String], dealReason: String?
    }

    func searchDeals(_ f: SearchFilters, offset: Int = 0) async throws -> SearchResults {
        var q = [URLQueryItem(name: "city", value: f.city), .init(name: "cat", value: f.category),
                 .init(name: "sort", value: "deal"), .init(name: "offset", value: "\(offset)")]
        if !f.query.isEmpty { q.append(.init(name: "q", value: f.query)) }
        if !f.minPrice.isEmpty { q.append(.init(name: "min_price", value: f.minPrice)) }
        if !f.maxPrice.isEmpty { q.append(.init(name: "max_price", value: f.maxPrice)) }
        if !f.postal.isEmpty { q.append(.init(name: "postal", value: f.postal)) }
        if !f.distance.isEmpty { q.append(.init(name: "search_distance", value: f.distance)) }
        if f.hasPhoto { q.append(.init(name: "hasPic", value: "1")) }

        var comps = URLComponents(string: "\(Self.workerAPI)/api/search")!
        comps.queryItems = q

        let (data, _) = try await session.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(WorkerSearchResponse.self, from: data)
        let listings = decoded.items.compactMap { i -> Listing? in
            guard let uuid = i.uuid else { return nil }
            return Listing(id: i.id, uuid: uuid, title: i.title, slug: i.slug, price: i.price,
                           priceString: i.priceString, postedDate: Date(timeIntervalSince1970: i.postedDate),
                           location: i.location, lat: i.lat, lon: i.lon, images: i.images,
                           dealReason: i.dealReason)
        }
        return SearchResults(listings: listings, total: decoded.total, cityName: decoded.location?.city)
    }

    // MARK: - Decoding
    //
    // Search results arrive as bare positional arrays against a per-response
    // dictionary, so JSONSerialization is the honest tool here; Codable would
    // just be a pile of unkeyed-container boilerplate over the same work.
    //
    //   [0] postingId offset from decode.minPostingId
    //   [1] postedDate offset from decode.minPostedDate
    //   [2] categoryId
    //   [3] price, -1 = none
    //   [4] "<locations idx>:<locationDescriptions idx>~lat~lon"
    //   last title
    // Between [5] and the title sit [tag, values...] arrays in no fixed order:
    //   4 = images, 6 = slug, 10 = priceString, 13 = postingUuid

    static func decodeSearch(_ data: Data) throws -> SearchResults {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let errors = root["errors"] as? [[String: Any]], let first = errors.first,
           let message = first["message"] as? String {
            throw Failure.upstream(message)
        }
        guard let payload = root["data"] as? [String: Any],
              let raw = payload["items"] as? [[Any]],
              let decode = payload["decode"] as? [String: Any] else {
            throw Failure.upstream("Unexpected response from Craigslist.")
        }

        let minID = decode["minPostingId"] as? Int ?? 0
        let minDate = decode["minPostedDate"] as? Double ?? 0
        let places = decode["locationDescriptions"] as? [Any] ?? []
        let listings = raw.compactMap { decodeItem($0, minID: minID, minDate: minDate, places: places) }

        return SearchResults(listings: listings,
                             total: payload["totalResultCount"] as? Int ?? listings.count,
                             cityName: (payload["location"] as? [String: Any])?["city"] as? String)
    }

    static func decodeItem(_ item: [Any], minID: Int, minDate: Double, places: [Any]) -> Listing? {
        guard item.count > 6,
              let idOffset = item[0] as? Int,
              let dateOffset = item[1] as? Double,
              let title = item.last as? String else { return nil }

        var uuid: String?, slug: String?, priceString: String?
        var images: [String] = []
        for case let tagged as [Any] in item.dropFirst(6).dropLast() {
            guard let tag = tagged.first as? Int else { continue }
            let values = tagged.dropFirst().compactMap { $0 as? String }
            switch tag {
            case 4: images = values.map { "https://images.craigslist.org/" + stripTokenPrefix($0) }
            case 6: slug = values.first
            case 10: priceString = values.first
            case 13: uuid = values.first
            default: break
            }
        }
        guard let uuid else { return nil }

        // The neighbourhood label is indexed from inside the geo string; it has
        // no slot of its own, which is easy to get wrong by counting positions.
        var place: String?, lat: Double?, lon: Double?
        if let geo = item[4] as? String {
            let parts = geo.split(separator: "~")
            if let idx = parts.first?.split(separator: ":").last.flatMap({ Int($0) }),
               places.indices.contains(idx) {
                place = places[idx] as? String
            }
            if parts.count >= 3 { lat = Double(parts[1]); lon = Double(parts[2]) }
        }

        let rawPrice = item[3] as? Int
        return Listing(id: minID + idOffset,
                       uuid: uuid,
                       title: title,
                       slug: slug,
                       price: rawPrice == -1 ? nil : rawPrice,
                       priceString: priceString,
                       postedDate: Date(timeIntervalSince1970: minDate + dateOffset),
                       location: place,
                       lat: lat,
                       lon: lon,
                       images: images)
    }

    static func stripTokenPrefix(_ token: String) -> String {
        guard let colon = token.firstIndex(of: ":"),
              token[token.startIndex..<colon].allSatisfy(\.isNumber) else { return token }
        return String(token[token.index(after: colon)...])
    }

    // MARK: - Detail

    /// Keyed by the tag-13 uuid, not the posting id. Hand-built
    /// `<city>.craigslist.org/.../<id>.html` URLs 404; use the `url` field here.
    func detail(uuid: String) async throws -> PostingDetail {
        let url = URL(string: "\(Self.sapi)/\(uuid)?cc=US&lang=en")!
        let (data, _) = try await session.data(from: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let item = ((root["data"] as? [String: Any])?["items"] as? [[String: Any]])?.first else {
            let message = (root["errors"] as? [[String: Any]])?.first?["message"] as? String
            throw Failure.upstream(message ?? "That posting is gone.")
        }

        let attrs = (item["attributes"] as? [[String: Any]] ?? []).compactMap { a -> (String, String)? in
            guard let l = a["label"] as? String, let v = a["value"] as? String else { return nil }
            return (l, v)
        }
        let images = (item["images"] as? [String] ?? []).compactMap {
            URL(string: "https://images.craigslist.org/" + Self.stripTokenPrefix($0) + "_600x450.jpg")
        }

        return PostingDetail(title: item["title"] as? String ?? "",
                             body: Self.sanitize(item["body"] as? String ?? ""),
                             priceString: item["priceString"] as? String,
                             location: (item["location"] as? [String: Any])?["description"] as? String,
                             attributes: attrs,
                             images: images,
                             url: (item["url"] as? String).flatMap(URL.init(string:)))
    }

    /// Posting bodies are HTML written by strangers, so they get collapsed to
    /// plain text before anything renders them. Deliberately not
    /// `NSAttributedString(html:)`, which spins up WebKit to parse hostile markup.
    static func sanitize(_ html: String) -> String {
        var s = html
        for (pattern, replacement) in [("<br\\s*/?>\\s*", "\n"), ("</p>\\s*", "\n\n"), ("<[^>]*>", "")] {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        for (entity, char) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"),
                               ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Craigslist publishes no area directory, so the id is read off the city's own
/// search page and kept forever -- these never change.
actor AreaDirectory {
    static let shared = AreaDirectory()

    private static let defaultsKey = "curbside.areaIds"
    private var cache: [String: Int]

    init(seed: [String: Int] = AreaDirectory.bundledSeed()) {
        let stored = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: Int] ?? [:]
        cache = seed.merging(stored) { _, stored in stored }
    }

    func id(for city: String, session: URLSession) async throws -> Int? {
        if let hit = cache[city] { return hit }
        let url = URL(string: "https://www.craigslist.org/search/area/\(city)")!
        let (data, response) = try await session.data(from: url)
        // Craigslist 404s cleanly on an unknown slug.
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8),
              let match = html.range(of: "\"areaId\":\\d+", options: .regularExpression),
              let id = Int(html[match].split(separator: ":")[1]) else { return nil }

        cache[city] = id
        UserDefaults.standard.set(cache, forKey: Self.defaultsKey)
        return id
    }

    private static func bundledSeed() -> [String: Int] {
        guard let url = Bundle.main.url(forResource: "areas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return seed
    }
}
