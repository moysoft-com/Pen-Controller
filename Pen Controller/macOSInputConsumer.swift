import Foundation
import SwiftUI

#if os(macOS)
import AppKit
import Combine
import ApplicationServices

final class InputConsumerState: ObservableObject {
    @Published var lastEventTime: TimeInterval = 0
    @Published var isReceiving = false
    @Published var isConnected = false
    @Published var connectedPeerName: String? = nil
    @Published var lastPressureState: PressureState = .move
}

final class InputConsumer {
    private let transport = MultipeerTransport(role: .advertiser)
    private let processor: InputProcessor
    private var lastEventTimestamp: TimeInterval = 0
    private var lastReceiveTime = Date()
    private let minInterval: TimeInterval

    init(config: InputProcessingConfig, maxHz: Double = 240) {
        processor = InputProcessor(config: config)
        minInterval = 1 / maxHz
    }

    func start(state: InputConsumerState) {
        transport.onReceiveData = { [weak self] data in
            guard let event = PacketCodec.decode(data) else { return }
            self?.handle(event: event, state: state)
        }
        transport.start()
    }

    func observeConnection(state: InputConsumerState) {
        transport.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { isConnected in
                state.isConnected = isConnected
            }
            .store(in: &cancellables)

        transport.$connectedPeerName
            .receive(on: DispatchQueue.main)
            .sink { name in
                state.connectedPeerName = name
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func handle(event: InputEvent, state: InputConsumerState) {
        let now = Date()
        defer { lastReceiveTime = now }
        if now.timeIntervalSince(lastReceiveTime) > 1.0 {
            lastEventTimestamp = 0
        }
        guard event.timestamp - lastEventTimestamp >= minInterval || lastEventTimestamp == 0 else {
            return
        }
        lastEventTimestamp = event.timestamp

        let delta = SIMD2<Double>(event.deltaX, event.deltaY)
        let processed = processor.process(delta: delta)
        applyMouseMovement(delta: processed)
        applyButtonState(event: event)

        state.lastEventTime = event.timestamp
        state.isReceiving = true
        if state.connectedPeerName == nil {
            state.connectedPeerName = "iPad"
        }
        state.lastPressureState = event.pressureState
    }

    private func applyMouseMovement(delta: SIMD2<Double>) {
        guard let screen = NSScreen.main else { return }
        let location = NSEvent.mouseLocation
        let newPoint = CGPoint(
            x: min(max(location.x + delta.x, 0), screen.frame.width),
            y: min(max(location.y - delta.y, 0), screen.frame.height)
        )
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newPoint, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    private func applyButtonState(event: InputEvent) {
        let location = NSEvent.mouseLocation
        let mouseType: CGEventType
        let button: CGMouseButton = .left

        switch event.pressureState {
        case .move:
            mouseType = .leftMouseUp
        case .click:
            mouseType = .leftMouseDown
        case .drag:
            mouseType = .leftMouseDragged
        }

        if let cgEvent = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: location, mouseButton: button) {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}

struct InputConsumerView: View {
    @StateObject private var state = InputConsumerState()
    private let consumer: InputConsumer

    init(config: InputProcessingConfig) {
        self.consumer = InputConsumer(config: config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pen Controller")
                .font(.title2)
            Text("Ready to pair over Bluetooth")
                .foregroundStyle(.secondary)

            ConnectionStatusCard(isConnected: state.isConnected, peerName: state.connectedPeerName)

            VStack(alignment: .leading, spacing: 6) {
                Text("Streaming")
                    .font(.headline)
                Text("Status: \(state.isReceiving ? "Receiving" : "Idle")")
                Text("Last event: \(state.lastEventTime, specifier: "%.3f")")
                Text("Pressure state: \(state.lastPressureState.rawValue)")
            }

            Text("Make sure Accessibility permissions are enabled so the cursor can move.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            if !AXIsProcessTrusted() {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            consumer.start(state: state)
            consumer.observeConnection(state: state)
        }
    }
}
#endif
