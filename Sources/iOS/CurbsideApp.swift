import SwiftUI

@main
struct CurbsideApp: App {
    @StateObject private var favorites = Favorites()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(favorites)
        }
    }
}

struct RootView: View {
    @StateObject private var model = SearchModel()
    @EnvironmentObject private var favorites: Favorites
    @State private var selection: Listing?
    @State private var showingFilters = false

    var body: some View {
        TabView {
            NavigationStack { browse }
                .tabItem { Label("Browse", systemImage: "magnifyingglass") }
            NavigationStack { saved }
                .tabItem { Label("Saved", systemImage: "star") }
        }
    }

    private var browse: some View {
        ResultsList(model: model, selection: $selection, savedOnly: nil)
            .navigationTitle("Curbside")
            .navigationDestination(for: Listing.self) { ListingDetailView(listing: $0) }
            .searchable(text: $model.filters.query, prompt: "Search listings")
            .onSubmit(of: .search) { Task { await model.run() } }
            .toolbar { filterButton }
            .sheet(isPresented: $showingFilters) { filterSheet }
    }

    private var saved: some View {
        ResultsList(model: model, selection: $selection, savedOnly: favorites.items)
            .navigationTitle("Saved")
            .navigationDestination(for: Listing.self) { ListingDetailView(listing: $0) }
    }

    private var filterButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showingFilters = true } label: { Label("Filters", systemImage: "slider.horizontal.3") }
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            FiltersView(filters: $model.filters) {
                showingFilters = false
                Task { await model.run() }
            }
            .navigationTitle("Filters")
        }
    }
}
