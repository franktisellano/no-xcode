import SwiftUI

struct ContentView: View {
    let model: CounterModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(model.count)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("count-label")

                Button("Increment") {
                    withAnimation { model.increment() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("increment-button")

                NavigationLink("Details") {
                    DetailView(count: model.count)
                }
                .accessibilityIdentifier("details-link")
            }
            .navigationTitle("__DISPLAY_NAME__")
            .toolbar {
                Button("Reset") { model.reset() }
                    .accessibilityIdentifier("reset-button")
            }
        }
    }
}

struct DetailView: View {
    let count: Int

    var body: some View {
        List {
            LabeledContent("Count", value: "\(count)")
            LabeledContent("Test mode", value: TestMode.isActive ? "On" : "Off")
        }
        .navigationTitle("Details")
        .accessibilityIdentifier("detail-list")
    }
}

#Preview {
    ContentView(model: .seeded())
}
