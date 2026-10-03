import SwiftUI

/// The results column. Both shells wrap this; only the chrome around it differs.
struct ResultsList: View {
    @ObservedObject var model: SearchModel
    @Binding var selection: Listing?
    var savedOnly: [Listing]?
    /// The macOS shell drives its detail column from the selection. In iPhone's plain
    /// NavigationStack a List selection binding swallows the tap, so rows never navigate.
    var usesSelection = true

    private var listings: [Listing] { savedOnly ?? model.listings }

    var body: some View {
        Group {
            if usesSelection {
                List(listings, selection: $selection) { row($0) }
            } else {
                List(listings) { row($0) }
            }
        }
        .overlay { statusOverlay }
    }

    private func row(_ listing: Listing) -> some View {
        NavigationLink(value: listing) { ListingRow(listing: listing) }
    }

    @ViewBuilder private var statusOverlay: some View {
        if model.isLoading {
            ProgressView()
        } else if listings.isEmpty {
            ContentUnavailableView(model.message ?? "Search to begin.",
                                   systemImage: "magnifyingglass")
        }
    }
}
