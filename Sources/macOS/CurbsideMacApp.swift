import SwiftUI

@main
struct CurbsideMacApp: App {
    @StateObject private var favorites = Favorites()

    var body: some Scene {
        WindowGroup {
            MacRootView().environmentObject(favorites)
        }
        .defaultSize(width: 1080, height: 720)
    }
}

struct MacRootView: View {
    @StateObject private var model = SearchModel()
    @EnvironmentObject private var favorites: Favorites
    @State private var selection: Listing?
    @State private var showingSaved = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            results
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        FiltersView(filters: $model.filters) { Task { await model.run() } }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }

    private var results: some View {
        ResultsList(model: model, selection: $selection,
                    savedOnly: showingSaved ? favorites.items : nil)
            .navigationTitle(showingSaved ? "Saved" : "Curbside")
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
            .toolbar {
                Toggle(isOn: $showingSaved) { Label("Saved", systemImage: "star") }
            }
    }

    @ViewBuilder private var detail: some View {
        if let selection {
            ListingDetailView(listing: selection)
        } else {
            ContentUnavailableView("Pick a listing", systemImage: "sidebar.right")
        }
    }
}
