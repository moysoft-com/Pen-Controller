import SwiftUI
import MultipeerConnectivity

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
                    .navigationTitle("Pen Controller")
            }
        } else {
            UnsupportedPlatformView()
        }
        #elseif os(macOS)
        InputConsumerView(config: config)
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
    @StateObject private var transport = MultipeerTransport(role: .browser)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pair with your Mac")
                        .font(.title2)
                    Text("Bluetooth automatically handles the connection. Choose your Mac below, then start drawing with Apple Pencil.")
                        .foregroundStyle(.secondary)
                }

                ConnectionStatusCard(isConnected: state.isConnected, peerName: state.connectedPeerName)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nearby Macs")
                        .font(.headline)
                    if transport.availablePeers.isEmpty {
                        Text("Searching for nearby Macs…")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(transport.availablePeers, id: \.self) { peer in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(peer.displayName)
                                    if transport.connectedPeers.contains(peer) {
                                        Text("Connected")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                                Spacer()
                                Button(transport.connectedPeers.contains(peer) ? "Connected" : "Connect") {
                                    transport.invite(peer: peer)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(transport.connectedPeers.contains(peer))
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Streaming")
                        .font(.headline)
                    Text("Status: \(state.isSending ? "Streaming" : "Idle")")
                    Text("Force: \(state.lastForce, specifier: "%.2f")")
                    Text("Pressure state: \(state.lastState.rawValue)")
                    Text("Timestamp: \(state.lastTimestamp, specifier: "%.3f")")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .onReceive(transport.$isConnected) { isConnected in
            state.isConnected = isConnected
        }
        .onReceive(transport.$connectedPeerName) { name in
            state.connectedPeerName = name
        }
        .onAppear {
            transport.start()
        }
        .onDisappear {
            transport.stop()
        }
        .background(
            InputProducerView(
                state: state,
                transport: transport,
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
