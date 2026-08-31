import SwiftUI

@main
struct CurbsideApp: App {
    @StateObject private var favorites = Favorites()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(favorites)
            .shareApp("https://curbside.heyitsmejosh.com")
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

// MARK: - Share

// ponytail: one overlay rather than a per-screen toolbar button — these root views share no
// navigation container to hang a .toolbar on. Move it into a toolbar per screen if this ever
// covers something that matters.
private struct AppShareOverlay: ViewModifier {
    let link: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if let url = URL(string: link) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .padding(10)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
    }
}

private extension View {
    func shareApp(_ link: String) -> some View { modifier(AppShareOverlay(link: link)) }
}
