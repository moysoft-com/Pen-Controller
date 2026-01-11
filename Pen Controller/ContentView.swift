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
            NavigationStack {
                InputProducerScreen(config: config)
                    .navigationTitle("Input Producer")
            }
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
    @State private var isConnecting = false
    @AppStorage("destinationHost") private var destinationHost: String = "255.255.255.255"
    @AppStorage("destinationPort") private var destinationPort: Int = 9999
    @State private var showingConnectSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Input Producer (iPadOS)")
                .font(.title2)
            Text("Status: \(state.isSending ? "Streaming" : "Idle")")
            Text("Force: \(state.lastForce, specifier: "%.2f")")
            Text("Pressure state: \(state.lastState.rawValue)")
            Text("Timestamp: \(state.lastTimestamp, specifier: "%.3f")")
            Text("Destination: \(destinationHost):\(destinationPort)")
                .foregroundStyle(.secondary)
            
            if state.isConnected {
                Text("Connection: Connected to \(state.connectedPeerName ?? destinationHost)")
                    .foregroundStyle(.green)
            } else if isConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting to \(destinationHost):\(destinationPort)...")
                }
            } else {
                Text("Connection: Not connected")
                    .foregroundStyle(.secondary)
            }
            
            Text("Point Apple Pencil here to stream deltas over UDP.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .onChange(of: state.isConnected) { newValue in
            if newValue { isConnecting = false }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Connect") { showingConnectSheet = true }
            }
        }
        .sheet(isPresented: $showingConnectSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Destination")) {
                        TextField("Host (e.g. 192.168.1.10)", text: $destinationHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField("Port", value: $destinationPort, format: .number)
                            .keyboardType(.numberPad)
                    }
                    Section(footer: Text("Enter your Mac's IP address and the UDP port the macOS app listens on.")) {
                        EmptyView()
                    }
                }
                .navigationTitle("Connect")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingConnectSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isConnecting = true
                            showingConnectSheet = false
                        }
                    }
                }
            }
        }
        .background(
            InputProducerView(
                state: state,
                destinationHost: destinationHost,
                destinationPort: UInt16(clamping: destinationPort),
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
