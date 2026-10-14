import Foundation
import Observation

/// Example domain model. Keep logic in plain Swift types like this so it is unit-testable
/// without any UI (see __APP__Tests).
@Observable
final class CounterModel {
    private(set) var count: Int

    init(count: Int = 0) {
        self.count = count
    }

    func increment() { count += 1 }
    func reset() { count = 0 }
}
