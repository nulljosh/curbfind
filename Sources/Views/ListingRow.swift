import SwiftUI

struct ListingRow: View {
    let listing: Listing
    @EnvironmentObject private var favorites: Favorites

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            details
            Spacer(minLength: 0)
            saveButton
        }
        .padding(.vertical, 6)
    }

    private var thumbnail: some View {
        AsyncImage(url: listing.thumbURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(listing.priceString ?? "—").font(.headline)
            Text(listing.title).font(.subheadline).lineLimit(2)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let when = listing.postedDate.formatted(.relative(presentation: .numeric))
        return [listing.location, when].compactMap { $0 }.joined(separator: " · ")
    }

    private var saveButton: some View {
        Button {
            favorites.toggle(listing)
        } label: {
            Image(systemName: favorites.contains(listing) ? "star.fill" : "star")
        }
        .buttonStyle(.plain)
        .foregroundStyle(favorites.contains(listing) ? .yellow : .secondary)
        .accessibilityLabel(favorites.contains(listing) ? "Remove from saved" : "Save listing")
    }
}
