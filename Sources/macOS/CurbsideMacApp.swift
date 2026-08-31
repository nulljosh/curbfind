import SwiftUI

@main
struct CurbsideMacApp: App {
    @StateObject private var favorites = Favorites()

    var body: some Scene {
        WindowGroup {
            MacRootView().environmentObject(favorites)
            .shareApp("https://curbside.heyitsmejosh.com")
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
