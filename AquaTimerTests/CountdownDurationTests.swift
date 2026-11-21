import XCTest

final class CountdownDurationTests: XCTestCase {
    func testParsesDurationAtSupportedBoundaries() {
        XCTAssertEqual(CountdownDuration.seconds(hours: "0", minutes: "0", seconds: "1"), 1)
        XCTAssertEqual(CountdownDuration.seconds(hours: "1", minutes: "2", seconds: "3"), 3_723)
        XCTAssertEqual(CountdownDuration.seconds(hours: "23", minutes: "59", seconds: "59"), 86_399)
        XCTAssertEqual(CountdownDuration.seconds(hours: " 0 ", minutes: "25", seconds: "00"), 1_500)
    }

    func testRejectsZeroAndOutOfRangeComponents() {
        let values = [("0", "0", "0"), ("24", "0", "0"), ("0", "60", "0"), ("0", "0", "60")]
        for (hours, minutes, seconds) in values {
            XCTAssertNil(CountdownDuration.seconds(hours: hours, minutes: minutes, seconds: seconds))
        }
    }

    func testRejectsMalformedAndOverflowingInput() {
        for input in ["", "-1", "+1", "1.5", "1e2", "abc", "999999999999999999999999999999"] {
            XCTAssertNil(CountdownDuration.seconds(hours: "0", minutes: "1", seconds: input), input)
        }
    }

    func testDisplayRoundsUpUntilTimerActuallyFinishes() {
        let values: [(TimeInterval, String)] = [
            (0, "00:00"), (0.01, "00:01"), (1.01, "00:02"),
            (59.01, "01:00"), (60, "01:00"), (3_600, "01:00:00"),
            (3_723, "01:02:03"), (86_399, "23:59:59")
        ]
        for (seconds, expected) in values {
            XCTAssertEqual(CountdownDuration.display(seconds), expected)
        }
    }
}
