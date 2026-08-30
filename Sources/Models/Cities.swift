import Foundation

/// Every Craigslist site worldwide, generated at build time by
/// scripts/fetch-cities.mjs so nothing scrapes at runtime.
struct City: Identifiable, Hashable, Decodable {
    let slug: String
    let name: String
    var id: String { slug }

    static let all: [City] = {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cities = try? JSONDecoder().decode([City].self, from: data) else {
            return [City(slug: "vancouver", name: "vancouver")]
        }
        return cities
    }()

    static func matching(_ text: String) -> [City] {
        let q = text.lowercased()
        guard !q.isEmpty else { return Array(all.prefix(40)) }
        return all.filter { $0.name.contains(q) || $0.slug.contains(q) }
    }
}
