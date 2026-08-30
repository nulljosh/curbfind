import SwiftUI

struct FiltersView: View {
    @Binding var filters: SearchFilters
    var onSearch: () -> Void

    @State private var cityQuery = ""

    var body: some View {
        Form {
            Section("Where") {
                Picker("City", selection: $filters.city) {
                    ForEach(City.matching(cityQuery)) { city in
                        Text(city.name).tag(city.slug)
                    }
                }
                TextField("Find a city", text: $cityQuery)
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
        }
    }
}
