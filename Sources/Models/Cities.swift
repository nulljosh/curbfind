import Foundation

/// Every Craigslist site worldwide, read live from Craigslist's area directory.
struct City: Identifiable, Hashable {
    let slug: String
    let name: String
    var id: String { slug }

    static func load() async -> [City] {
        let areas = await AreaDirectory.shared.all()
        return areas.isEmpty ? [City(slug: "vancouver", name: "vancouver")] : areas.map { City(slug: $0.slug, name: $0.name) }
    }

    static func matching(_ text: String, in all: [City]) -> [City] {
        let q = text.lowercased()
        guard !q.isEmpty else { return Array(all.prefix(40)) }
        return all.filter { $0.name.contains(q) || $0.slug.contains(q) }
    }
}
