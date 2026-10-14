import SwiftUI

@main
struct __APP__App: App {
    @State private var model = TestMode.isActive ? CounterModel.seeded() : CounterModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
