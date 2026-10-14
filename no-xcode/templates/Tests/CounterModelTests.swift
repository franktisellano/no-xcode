import Testing
@testable import __APP__

struct CounterModelTests {
    @Test func incrementsAndResets() {
        let model = CounterModel()
        model.increment()
        model.increment()
        #expect(model.count == 2)
        model.reset()
        #expect(model.count == 0)
    }
}
