import Foundation
import SwiftUI

#if os(macOS)
import AppKit

final class InputConsumerState: ObservableObject {
    @Published var lastEventTime: TimeInterval = 0
    @Published var isReceiving = false
    @Published var lastPressureState: PressureState = .move
}

final class InputConsumer {
    private let server = UDPServer()
    private let processor: InputProcessor
    private var lastEventTimestamp: TimeInterval = 0
    private var lastReceiveTime = Date()
    private let minInterval: TimeInterval

    init(config: InputProcessingConfig, maxHz: Double = 240) {
        processor = InputProcessor(config: config)
        minInterval = 1 / maxHz
    }

    func start(port: UInt16, state: InputConsumerState) {
        server.onEvent = { [weak self] event in
            self?.handle(event: event, state: state)
        }
        server.start(port: port)
    }

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
    private let port: UInt16

    init(config: InputProcessingConfig, port: UInt16) {
        self.consumer = InputConsumer(config: config)
        self.port = port
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Consumer (macOS)")
                .font(.title2)
            Text("Status: \(state.isReceiving ? "Receiving" : "Idle")")
            Text("Last event: \(state.lastEventTime, specifier: "%.3f")")
            Text("Pressure state: \(state.lastPressureState.rawValue)")
            Text("Ensure Accessibility permissions are granted.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            consumer.start(port: port, state: state)
        }
    }
}
#endif
