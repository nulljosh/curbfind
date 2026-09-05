import XCTest
@testable import Curbfind

/// Decodes the same worker/fixtures/search.json the JS decoder is pinned to, so
/// the two ports cannot drift apart without one of them going red.
final class CraigslistAPITests: XCTestCase {
    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "search-fixture", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDecodesEveryItem() throws {
        let results = try CraigslistAPI.decodeSearch(fixture())
        XCTAssertGreaterThan(results.listings.count, 100)
        XCTAssertEqual(results.total, 1611)
        for listing in results.listings {
            XCTAssertFalse(listing.title.isEmpty)
            XCTAssertEqual(String(listing.id).count, 10, "offsets must rebuild a real posting id")
            XCTAssertGreaterThanOrEqual(listing.uuid.count, 20)
            XCTAssertNotNil(listing.url)
        }
    }

    func testFirstItemMatchesTheLiveValuesItWasCapturedWith() throws {
        let first = try XCTUnwrap(CraigslistAPI.decodeSearch(fixture()).listings.first)
        XCTAssertEqual(first.id, 7957784777)
        XCTAssertEqual(first.uuid, "81sCtMbL4Q6jLnxcjZQ4Qm")
        XCTAssertEqual(first.price, 70)
        XCTAssertEqual(first.priceString, "$70")
        XCTAssertEqual(first.location, "Vancouver", "the place label is indexed from inside the geo string")
        XCTAssertEqual(first.postedDate.timeIntervalSince1970, 1788122239, accuracy: 1)
        XCTAssertEqual(first.images.count, 3)
        XCTAssertEqual(first.thumbURL?.absoluteString,
                       "https://images.craigslist.org/00J0J_jCrtEigzgOj_0CI0t2_300x300.jpg")
    }

    func testFreePostingsHaveNoPrice() throws {
        let listings = try CraigslistAPI.decodeSearch(fixture()).listings
        let free = try XCTUnwrap(listings.first { $0.priceString == "free" })
        XCTAssertNil(free.price, "-1 is Craigslist's sentinel, not a price")
    }

    func testUpstreamErrorsSurface() {
        let body = Data(#"{"data":{},"errors":[{"message":"bad details_length"}]}"#.utf8)
        XCTAssertThrowsError(try CraigslistAPI.decodeSearch(body))
    }

    func testSanitizeStripsMarkupAndKeepsLineStructure() {
        XCTAssertEqual(CraigslistAPI.sanitize("a<br>\nb"), "a\nb")
        XCTAssertEqual(CraigslistAPI.sanitize("<p>one</p><p>two</p>"), "one\n\ntwo")
        XCTAssertEqual(CraigslistAPI.sanitize("Tom &amp; Jerry &quot;hi&quot;"), "Tom & Jerry \"hi\"")
    }

    func testSanitizeDefusesAHostileBody() {
        let out = CraigslistAPI.sanitize(#"<img src=x onerror="alert(1)"><script>steal()</script>call me"#)
        XCTAssertFalse(out.contains("<"))
        XCTAssertFalse(out.contains("onerror"))
        XCTAssertTrue(out.hasSuffix("call me"))
    }

    func testStripTokenPrefixOnlyDropsANumericPrefix() {
        XCTAssertEqual(CraigslistAPI.stripTokenPrefix("3:00J0J_abc"), "00J0J_abc")
        XCTAssertEqual(CraigslistAPI.stripTokenPrefix("00J0J_abc"), "00J0J_abc")
    }

    // MARK: - Edge cases

    func testDecodeSearchOnZeroResultsReturnsAnEmptyListNotAThrow() throws {
        let body = Data(#"{"data":{"items":[],"totalResultCount":0,"decode":{"minPostingId":0,"minPostedDate":0,"locationDescriptions":[]}}}"#.utf8)
        let results = try CraigslistAPI.decodeSearch(body)
        XCTAssertEqual(results.listings, [])
        XCTAssertEqual(results.total, 0)
    }

    func testDecodeSearchOnCompletelyMalformedJSONThrowsRatherThanCrashing() {
        let body = Data("not json at all".utf8)
        XCTAssertThrowsError(try CraigslistAPI.decodeSearch(body))
    }

    func testDecodeSearchOnValidJSONMissingTheDataKeyThrowsAReadableFailure() {
        let body = Data(#"{"unexpected":true}"#.utf8)
        XCTAssertThrowsError(try CraigslistAPI.decodeSearch(body)) { error in
            guard case CraigslistAPI.Failure.upstream = error else {
                return XCTFail("expected .upstream, got \(error)")
            }
        }
    }

    func testDecodeItemWithoutAUuidIsDroppedRatherThanCrashing() {
        // Six leading positional fields, then only a title -- no tagged uuid array at all.
        let item: [Any] = [1, 1.0, "sss", -1, "0:0~0~0", "abc", "No uuid here"]
        let listing = CraigslistAPI.decodeItem(item, minID: 1000, minDate: 1_700_000_000, places: [])
        XCTAssertNil(listing, "a listing with no uuid has no stable identity and no canonical URL")
    }

    func testDecodeItemWithAnOutOfRangeLocationIndexFallsBackToNilPlace() {
        let item: [Any] = [1, 1.0, "sss", 5, "0:99~49.28~-123.12", "abc", [13, "uuid123"] as [Any], "Title"]
        let listing = try? XCTUnwrap(CraigslistAPI.decodeItem(item, minID: 1000, minDate: 1_700_000_000, places: ["Only one entry"]))
        XCTAssertNil(listing?.location)
        XCTAssertEqual(listing?.lat, 49.28)
        XCTAssertEqual(listing?.lon, -123.12)
    }

    func testSanitizeOnEmptyAndNilLikeInputNeverThrows() {
        XCTAssertEqual(CraigslistAPI.sanitize(""), "")
    }
}
