import Foundation
import SwiftTUI

// ponytail: reuses CraigslistAPI.swift as-is, the exact client the native iOS/macOS
// apps use, no server, no disguise, per its own header comment. `curbside-tui <query>
// [city]` searches and lists results.

let args = CommandLine.arguments.dropFirst()
guard let query = args.first else {
    print("usage: curbside-tui <query> [city]")
    exit(1)
}
let city = args.count > 1 ? Array(args)[1] : "vancouver"

var filters = SearchFilters()
filters.query = query
filters.city = city

func runSearch() async -> Result<CraigslistAPI.SearchResults, Error> {
    do { return .success(try await CraigslistAPI().search(filters)) }
    catch { return .failure(error) }
}

struct ResultsCard: View {
    let query: String
    let result: Result<CraigslistAPI.SearchResults, Error>

    var body: some View {
        VStack(alignment: .leading) {
            Text("curbside: \(query)").bold()
            switch result {
            case .success(let r):
                Text("\(r.total) results in \(r.cityName ?? city)")
                ForEach(r.listings.prefix(8)) { l in
                    Text("\(l.priceString ?? "—") · \(l.title)")
                }
            case .failure(let error):
                Text("Error: \(error.localizedDescription)")
            }
        }
        .padding()
        .border()
    }
}

let semaphore = DispatchSemaphore(value: 0)
var result: Result<CraigslistAPI.SearchResults, Error>!
Task {
    result = await runSearch()
    semaphore.signal()
}
semaphore.wait()

Application(rootView: ResultsCard(query: query, result: result)).start()
