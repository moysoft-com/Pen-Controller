//
//  InputConsumerView.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

#if os(macOS)
import AppKit
import SwiftUI

final class MouseButtonEmulator {
    private var isDragging = false

    func handle(state: PressureState, at location: CGPoint) {
        switch state {
        case .move:
            if isDragging {
                post(mouseType: .leftMouseUp, location: location)
                isDragging = false
            }
        case .click:
            post(mouseType: .leftMouseDown, location: location)
            post(mouseType: .leftMouseUp, location: location)
        case .drag:
            if !isDragging {
                post(mouseType: .leftMouseDown, location: location)
                isDragging = true
            }
        }
    }

    private func post(mouseType: CGEventType, location: CGPoint) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: location, mouseButton: .left) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }
}

final class InputConsumerViewModel: ObservableObject {
    @Published var port: String = "50505"
    @Published var receivedCount: Int = 0
    @Published var lastState: PressureState = .move
    @Published var statusText: String = "Idle"

    private let receiver = UDPEventReceiver()
    private let filter = InputFilter(smoothingFactor: 0.2, accelerationCurve: 0.45, speedThreshold: 14)
    private let rateLimiter = RateLimiter(minimumInterval: 1.0 / 240.0)
    private let driftCorrector = DriftCorrector()
    private let buttonEmulator = MouseButtonEmulator()

    init() {
        receiver.onEvent = { [weak self] event in
            self?.handle(event: event)
        }
    }

    func start() {
        guard let portValue = UInt16(port) else { return }
        receiver.startListening(port: portValue)
        statusText = "Listening on \(portValue)"
    }

    func stop() {
        receiver.stop()
        statusText = "Stopped"
    }

    private func handle(event: InputEvent) {
        guard rateLimiter.allows(timestamp: event.timestamp) else { return }
        let filtered = filter.process(
            delta: CGPoint(x: event.deltaX, y: event.deltaY),
            timestamp: event.timestamp
        )
        let corrected = driftCorrector.apply(to: filtered)
        if corrected == .zero { return }
        let currentLocation = NSEvent.mouseLocation
        let target = CGPoint(x: currentLocation.x + corrected.x, y: currentLocation.y - corrected.y)
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else { return }
        moveEvent.post(tap: .cghidEventTap)
        buttonEmulator.handle(state: event.pressureState, at: target)
        receivedCount += 1
        lastState = event.pressureState
    }
}

struct InputConsumerView: View {
    @StateObject private var model = InputConsumerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Input Consumer (macOS)")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                Text("Listening Port")
                    .font(.caption)
                TextField("Port", text: $model.port)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Start") {
                    model.start()
                }
                .buttonStyle(.borderedProminent)

                Button("Stop") {
                    model.stop()
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 6) {
                Text(model.statusText)
                Text("Received events: \(model.receivedCount)")
                Text("Last state: \(model.lastState.rawValue.capitalized)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer()

            Text("Grant Accessibility permission so the app can control the cursor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
#endif
