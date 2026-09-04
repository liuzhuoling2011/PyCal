import XCTest
@testable import PyCal

@MainActor
final class TimeConverterTests: XCTestCase {
    func testDateToTimestampAcrossUnits() {
        let store = TimeConverterStore()
        store.dateValue = Date(timeIntervalSince1970: 1_735_790_147.25)

        store.unit = .seconds
        store.convertDateToTimestamp()
        XCTAssertEqual(store.dateOutput, "1735790147.25")

        store.unit = .milliseconds
        store.convertDateToTimestamp()
        XCTAssertEqual(store.dateOutput, "1735790147250")

        store.unit = .nanoseconds
        store.convertDateToTimestamp()
        XCTAssertFalse(store.dateOutput.contains(","))
        XCTAssertFalse(store.dateOutput.contains(" "))
        XCTAssertTrue(store.dateOutput.allSatisfy(\.isNumber))
    }

    func testTimestampToDateUsesSelectedTimezone() {
        let store = TimeConverterStore()
        store.unit = .seconds
        store.setTimezone("Asia/Shanghai")
        store.timestampInput = "0"
        store.convertTimestampToDate()
        XCTAssertEqual(store.timestampOutput, "1970-01-01 08:00:00")
        XCTAssertNil(store.timestampError)
    }

    func testDateInputAcceptsSlashAndOptionalSeconds() {
        let store = TimeConverterStore()
        store.setTimezone("Asia/Shanghai")
        store.dateInput = "1970/01/01 08:00"
        store.convertDateInput()
        XCTAssertEqual(store.dateOutput, "0")
        XCTAssertNil(store.dateError)
    }
}
