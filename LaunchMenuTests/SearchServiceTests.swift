import XCTest
@testable import LaunchMenu

final class SearchServiceTests: XCTestCase {
    private let service = BasicSearchService()

    func testSearchReturnsAllItemsForEmptyQuery() async {
        let items = [
            LaunchItem(title: "Safari"),
            LaunchItem(title: "Notes")
        ]

        let results = await service.search(query: "", in: items)
        XCTAssertEqual(results.count, 2)
    }

    func testSearchMatchesHangulInitials() async {
        let items = [
            LaunchItem(title: "카카오톡"),
            LaunchItem(title: "메모")
        ]

        let results = await service.search(query: "ㅋㅋ", in: items)
        XCTAssertEqual(results.first?.title, "카카오톡")
    }

    func testSearchMatchesFuzzyQuery() async {
        let items = [
            LaunchItem(title: "Safari"),
            LaunchItem(title: "Calendar")
        ]

        let results = await service.search(query: "sfr", in: items)
        XCTAssertEqual(results.first?.title, "Safari")
    }
}
