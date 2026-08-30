import SwiftUI

struct ListingDetailView: View {
    let listing: Listing
    var api = CraigslistAPI()

    @State private var detail: PostingDetail?
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gallery
                header
                if let detail, !detail.attributes.isEmpty { attributes(detail) }
                bodyText
                if let link = detail?.url ?? listing.url {
                    Link("View original posting", destination: link)
                        .font(.body.weight(.semibold))
                }
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
        }
        .navigationTitle(listing.title)
        .task { await load() }
    }

    private var gallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(detail?.images ?? listing.imageURLs, id: \.self) { url in
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle().fill(.quaternary).frame(width: 220)
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(listing.priceString ?? "—").font(.title2.weight(.bold))
            Text(listing.title).font(.headline)
            if let place = detail?.location ?? listing.location {
                Text(place).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func attributes(_ detail: PostingDetail) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(detail.attributes, id: \.label) { attr in
                Text("\(attr.label): \(attr.value)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Text(), never an HTML renderer: the body is written by strangers and has
    // already been stripped to plain text by CraigslistAPI.sanitize.
    @ViewBuilder private var bodyText: some View {
        if let failure {
            Text(failure).foregroundStyle(.secondary)
        } else if let detail {
            Text(detail.body).textSelection(.enabled)
        } else {
            ProgressView()
        }
    }

    private func load() async {
        do { detail = try await api.detail(uuid: listing.uuid) }
        catch { failure = "Couldn't load this posting. Open the original instead." }
    }
}
