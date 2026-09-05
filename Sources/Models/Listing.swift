import Foundation

struct Listing: Identifiable, Hashable, Codable {
    let id: Int
    let uuid: String
    let title: String
    let slug: String?
    let price: Int?
    let priceString: String?
    let postedDate: Date
    let location: String?
    let lat: Double?
    let lon: Double?
    let images: [String]
    var dealReason: String? = nil

    var thumbURL: URL? { images.first.flatMap { URL(string: $0 + "_300x300.jpg") } }
    var imageURLs: [URL] { images.compactMap { URL(string: $0 + "_600x450.jpg") } }
    var url: URL? {
        guard let slug else { return nil }
        return URL(string: "https://www.craigslist.org/view/d/\(slug)/\(uuid)")
    }
}

struct PostingDetail {
    let title: String
    let body: String
    let priceString: String?
    let location: String?
    let attributes: [(label: String, value: String)]
    let images: [URL]
    let url: URL?
}

struct Category: Identifiable, Hashable {
    let id: String
    let name: String

    // Craigslist keeps these in its JS bundle, not in any document, but the
    // abbreviations have been stable for two decades. Each one verified live.
    static let all: [Category] = [
        .init(id: "sss", name: "For sale"),
        .init(id: "hhh", name: "Housing"),
        .init(id: "apa", name: "Apartments / housing"),
        .init(id: "bbb", name: "Jobs (all)"),
        .init(id: "jjj", name: "Jobs"),
        .init(id: "ggg", name: "Gigs"),
        .init(id: "cta", name: "Cars & trucks"),
        .init(id: "ccc", name: "Community"),
        .init(id: "rrr", name: "Resumes"),
    ]
}

struct SearchFilters: Equatable {
    var query = ""
    var category = "sss"
    var city = "vancouver"
    var minPrice = ""
    var maxPrice = ""
    var postal = ""
    var distance = ""
    var hasPhoto = false
    var sort = "rel"

    static let sorts = [("rel", "Best match"), ("deal", "Best deals"), ("date", "Newest"),
                        ("priceasc", "Price: low to high"), ("pricedsc", "Price: high to low")]
}
