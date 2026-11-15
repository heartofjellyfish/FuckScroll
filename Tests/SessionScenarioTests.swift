import Foundation

/// Virtual time, explicitly supplied usage callbacks, and the production state
/// machine. This cannot prove that iOS actually delivers those callbacks.
@main
struct SessionScenarioTests {
    static var results: [[String: String]] = []
    static let start = Date(timeIntervalSince1970: 1_790_000_000)
    static func check(_ name: String, _ condition: Bool, _ detail: String) {
        precondition(condition, "FAIL: \(name): \(detail)")
        results.append(["scenario": name, "result": "PASS", "evidence": detail])
        print("PASS: \(name) — \(detail)")
    }
    static func main() throws {
        var state = SessionState()
        state.open(at: start)
        state.confirmUsage(19 * 60)
        check("One more post", state.remaining(limit: 20) == 60, "19 delivered minutes leave one minute")
        state.confirmUsage(20 * 60)
        check("Threshold", state.remaining(limit: 20) == 0, "20 delivered minutes reach the limit")
        state.beginRest(at: start.addingTimeInterval(1200), minutes: 15)
        let deadline = state.cooldownUntil!
        for i in 1...30 {
            let date = start.addingTimeInterval(1200 + Double(i * 10))
            state.close(at: date)
            state.open(at: date.addingTimeInterval(2))
            state.finishRest(at: date.addingTimeInterval(3))
        }
        check("Angry reopening", state.cooldownUntil == deadline && state.openedAt == nil, "30 reopen/close attempts neither shorten nor extend the break")
        let data = try JSONEncoder().encode(state)
        state = try JSONDecoder().decode(SessionState.self, from: data)
        check("Process restart", state.isResting(at: deadline.addingTimeInterval(-1)), "encoded state retains the break until its deadline")
        state.finishRest(at: deadline)
        state.open(at: deadline)
        check("Come back later", state.remaining(limit: 20) == 1200, "the full allowance returns at expiry")

        var messages = SessionState()
        messages.open(at: start)
        messages.confirmUsage(12 * 60)
        messages.close(at: start.addingTimeInterval(720))
        messages.open(at: start.addingTimeInterval(750))
        messages.confirmUsage(20 * 60)
        check("Reply to a message", messages.remaining(limit: 20) == 0, "12 + 8 minutes count together across a 30-second switch")

        var tea = SessionState()
        tea.open(at: start)
        tea.confirmUsage(19 * 60)
        tea.close(at: start.addingTimeInterval(1140))
        tea.open(at: start.addingTimeInterval(1200))
        check("Actually leave", tea.remaining(limit: 20) == 1200, "a full minute away resets the unfinished session")

        var locked = SessionState()
        locked.open(at: start)
        locked.confirmUsage(60)
        locked.close(at: start.addingTimeInterval(7200))
        check("Phone left alone", locked.usedSeconds == 60, "two hours of wall time are not billed as two hours of scrolling")

        var repeated = SessionState()
        for index in 0..<3 {
            let date = start.addingTimeInterval(Double(index * 2100))
            repeated.finishRest(at: date)
            repeated.open(at: date)
            repeated.confirmUsage(1200)
            repeated.beginRest(at: date.addingTimeInterval(1200), minutes: 15)
        }
        check("Three returns", repeated.interruptions == 3, "mood escalates after three modeled interventions")

        // Regression: the old implementation stopped monitoring on every
        // close, so 30 × 59-second visits could consume zero confirmed minutes.
        var hopping = SessionState()
        var blockVisit = 0
        for index in 0..<30 {
            let date = start.addingTimeInterval(Double(index * 69))
            hopping.open(at: date)
            if index == 0 { hopping.activeMonitor = "retained-counter" }
            precondition(hopping.activeMonitor == "retained-counter")
            let cumulativeUse = Double((index + 1) * 59)
            hopping.confirmUsage(floor(cumulativeUse / 60) * 60)
            if hopping.remaining(limit: 20) <= 0 {
                hopping.beginRest(at: date.addingTimeInterval(59), minutes: 15)
                blockVisit = index + 1
                break
            }
            hopping.close(at: date.addingTimeInterval(59))
        }
        check("Sub-minute hopping regression", blockVisit == 21 && hopping.cooldownUntil != nil,
              "one retained monitor reaches the threshold during visit 21 when supplied cumulative system usage; no per-visit truncation")
        let report: [String: Any] = ["method": "production SessionState; virtual clock; injected callbacks; no system shielding", "results": results]
        let output = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: URL(fileURLWithPath: ".build/session-scenarios.json"))
    }
}
