import Foundation

/// Saved listings, stored whole so the Saved tab needs no network.
@MainActor
final class Favorites: ObservableObject {
    private static let key = "curbside.favorites"
    @Published private(set) var items: [Listing] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Listing].self, from: data) {
            items = saved
        }
    }

    func contains(_ listing: Listing) -> Bool { items.contains { $0.id == listing.id } }

    func toggle(_ listing: Listing) {
        if let i = items.firstIndex(where: { $0.id == listing.id }) {
            items.remove(at: i)
        } else {
            items.insert(listing, at: 0)
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// Drives one search. Shared by both platform shells.
@MainActor
final class SearchModel: ObservableObject {
    @Published var filters = SearchFilters()
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private let api: CraigslistAPI

    init(api: CraigslistAPI = CraigslistAPI()) { self.api = api }

    func run() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let results = filters.sort == "deal" ? try await api.searchDeals(filters) : try await api.search(filters)
            listings = results.listings
            total = results.total
            message = results.listings.isEmpty ? "No results." : nil
        } catch {
            listings = []
            total = 0
            message = error.localizedDescription
        }
    }
}
