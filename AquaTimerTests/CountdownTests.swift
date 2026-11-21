import XCTest

final class CountdownTests: XCTestCase {
    func testStartAndDelayedRefreshUseDeadline() {
        var timer = Countdown()
        timer.start(seconds: 90, at: 100)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.remaining, 90)

        timer.update(at: 128.75)
        XCTAssertEqual(timer.remaining, 61.25)
        timer.update(at: 171)
        XCTAssertEqual(timer.remaining, 19)
    }

    func testStartingAgainDoesNotExtendRunningTimer() {
        var timer = Countdown()
        timer.start(seconds: 90, at: 100)
        timer.start(seconds: 300, at: 120)
        timer.update(at: 130)
        XCTAssertEqual(timer.remaining, 60)
        XCTAssertEqual(timer.duration, 90)
    }

    func testPauseAndResumePreserveFractionalRemainingTime() {
        var timer = Countdown()
        timer.start(seconds: 90, at: 100)
        timer.pause(at: 125.5)
        XCTAssertEqual(timer.state, .paused)
        XCTAssertEqual(timer.remaining, 64.5)

        timer.update(at: 500)
        XCTAssertEqual(timer.remaining, 64.5)
        timer.resume(at: 500)
        timer.update(at: 510)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.remaining, 54.5)
    }

    func testPausingAfterDeadlineFinishesInsteadOfPausingAtZero() {
        var timer = Countdown()
        timer.start(seconds: 5, at: 100)
        timer.pause(at: 106)
        XCTAssertEqual(timer.state, .finished)
        XCTAssertEqual(timer.remaining, 0)
    }

    func testLargeTimeJumpFinishesAndSubsequentUpdatesStayFinished() {
        var timer = Countdown()
        timer.start(seconds: 60, at: 100)
        timer.update(at: 7_300)
        XCTAssertEqual(timer.state, .finished)
        XCTAssertEqual(timer.remaining, 0)

        timer.update(at: 7_400)
        timer.resume(at: 7_500)
        XCTAssertEqual(timer.state, .finished)
        XCTAssertEqual(timer.remaining, 0)
    }

    func testExactDeadlineFinishes() {
        var timer = Countdown()
        timer.start(seconds: 1, at: 100)
        timer.update(at: 101)
        XCTAssertEqual(timer.state, .finished)
        XCTAssertEqual(timer.remaining, 0)
    }

    func testResetRestoresConfiguredDurationAndStopsCountdown() {
        var timer = Countdown()
        timer.start(seconds: 90, at: 100)
        timer.pause(at: 125)
        timer.reset()
        timer.update(at: 500)
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.remaining, 90)
        timer.resume(at: 500)
        XCTAssertEqual(timer.state, .idle)
    }

    func testFinishedTimerCanStartWithANewDuration() {
        var timer = Countdown()
        timer.start(seconds: 1, at: 100)
        timer.update(at: 102)
        timer.start(seconds: 10, at: 200)
        timer.update(at: 203)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.remaining, 7)
    }

    func testInvalidDurationsCannotStart() {
        for seconds in [-1, 0, 86_400, Int.max] {
            var timer = Countdown()
            timer.start(seconds: seconds, at: 100)
            XCTAssertEqual(timer.state, .idle, "seconds: \(seconds)")
        }
    }

    func testInvalidClockValuesDoNotCorruptCountdown() {
        var timer = Countdown()
        timer.start(seconds: 10, at: .nan)
        XCTAssertEqual(timer.state, .idle)
        timer.start(seconds: 10, at: 100)
        timer.update(at: .infinity)
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.remaining, 10)
    }
}
