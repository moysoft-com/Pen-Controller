import SwiftUI

struct ContentView: View {
    private let config = InputProcessingConfig(
        forceClickThreshold: 0.2,
        forceDragThreshold: 0.6,
        smoothingFactor: 0.35,
        accelerationFactor: 0.04,
        minAcceleration: 0.6,
        maxAcceleration: 2.4,
        driftEpsilon: 0.02
    )

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            InputProducerScreen(config: config)
        } else {
            UnsupportedPlatformView()
        }
        #elseif os(macOS)
        InputConsumerView(config: config, port: 9999)
        #else
        UnsupportedPlatformView()
        #endif
    }
}

private struct UnsupportedPlatformView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Unsupported Platform")
                .font(.title2)
            Text("This build targets iPadOS (producer) and macOS (consumer).")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#if os(iOS)
private struct InputProducerScreen: View {
    let config: InputProcessingConfig
    @StateObject private var state = InputProducerState()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Input Producer (iPadOS)")
                .font(.title2)
            Text("Status: \(state.isSending ? "Streaming" : "Idle")")
            Text("Force: \(state.lastForce, specifier: "%.2f")")
            Text("Pressure state: \(state.lastState.rawValue)")
            Text("Timestamp: \(state.lastTimestamp, specifier: "%.3f")")
                .foregroundStyle(.secondary)
            Text("Point Apple Pencil here to stream deltas over UDP.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(
            InputProducerView(
                state: state,
                destinationHost: "255.255.255.255",
                destinationPort: 9999,
                config: config
            )
            .ignoresSafeArea()
        )
    }
}
#endif

#Preview {
    ContentView()
}
