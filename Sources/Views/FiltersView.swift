import SwiftUI

struct FiltersView: View {
    @Binding var filters: SearchFilters
    var onSearch: () -> Void

    @State private var cityQuery = ""
    @State private var cities: [City] = []
    @State private var nearMe = NearMe()
    @State private var locating = false
    @State private var locateError: String?

    /// The matches, always including the selected city so the picker never shows an empty selection.
    private var options: [City] {
        let m = City.matching(cityQuery, in: cities)
        return m.contains { $0.slug == filters.city } ? m : [City(slug: filters.city, name: filters.city)] + m
    }

    var body: some View {
        Form {
            #if os(macOS)
            // iOS gets this from .searchable on the results list.
            Section { TextField("Search listings", text: $filters.query) }
            #endif
            Section("Where") {
                Button(locating ? "Finding you…" : "Near me") { findMe() }
                    .disabled(locating)
                if let locateError { Text(locateError).font(.footnote).foregroundStyle(.secondary) }
                TextField("Find a city", text: $cityQuery)
                Picker("City", selection: $filters.city) {
                    ForEach(options) { city in
                        Text(city.name).tag(city.slug)
                    }
                }
                TextField("Postal or ZIP", text: $filters.postal)
                TextField("Distance (km)", text: $filters.distance)
            }
            Section("What") {
                Picker("Category", selection: $filters.category) {
                    ForEach(Category.all) { Text($0.name).tag($0.id) }
                }
                TextField("Min price", text: $filters.minPrice)
                TextField("Max price", text: $filters.maxPrice)
                Toggle("Has photo", isOn: $filters.hasPhoto)
                Picker("Sort", selection: $filters.sort) {
                    ForEach(SearchFilters.sorts, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            Button("Search", action: onSearch)
                .keyboardShortcut(.defaultAction)
        }
        .onSubmit(onSearch)
        .task { cities = await City.load() }
    }

    /// Nearest city to the device, ranked by deal, then search.
    private func findMe() {
        locating = true
        locateError = nil
        Task {
            defer { locating = false }
            do {
                let loc = try await nearMe.locate()
                guard let slug = await AreaDirectory.shared.nearest(lat: loc.coordinate.latitude,
                                                                    lon: loc.coordinate.longitude) else {
                    locateError = "Couldn't load the city list."
                    return
                }
                filters.city = slug
                filters.sort = "deal"
                onSearch()
            } catch {
                locateError = error.localizedDescription
            }
        }
    }
}
