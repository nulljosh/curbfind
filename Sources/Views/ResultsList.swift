import SwiftUI

/// The results column. Both shells wrap this; only the chrome around it differs.
struct ResultsList: View {
    @ObservedObject var model: SearchModel
    @Binding var selection: Listing?
    var savedOnly: [Listing]?

    private var listings: [Listing] { savedOnly ?? model.listings }

    var body: some View {
        List(listings, selection: $selection) { listing in
            NavigationLink(value: listing) { ListingRow(listing: listing) }
        }
        .overlay { statusOverlay }
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
