import Foundation
import SwiftUI
import Combine

#if os(iOS)
import UIKit

final class InputProducerState: ObservableObject {
    @Published var isSending = false
    @Published var lastForce: Double = 0
    @Published var lastState: PressureState = .move
    @Published var lastTimestamp: TimeInterval = 0
    @Published var isConnected: Bool = false
    @Published var connectedPeerName: String? = nil
}

struct InputProducerView: UIViewRepresentable {
    @ObservedObject var state: InputProducerState
    let transport: MultipeerTransport
    let config: InputProcessingConfig

    func makeUIView(context: Context) -> PencilInputView {
        let view = PencilInputView()
        view.configure(transport: transport, config: config, state: state)
        return view
    }

    func updateUIView(_ uiView: PencilInputView, context: Context) {
        uiView.updateConfig(config)
        uiView.updateTransport(transport)
    }
}

final class PencilInputView: UIView {
    private var transport: MultipeerTransport?
    private var processor: InputProcessor?
    private weak var state: InputProducerState?
    private var lastLocation: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(transport: MultipeerTransport, config: InputProcessingConfig, state: InputProducerState) {
        self.transport = transport
        processor = InputProcessor(config: config)
        self.state = state
    }

    func updateConfig(_ config: InputProcessingConfig) {
        processor = InputProcessor(config: config)
    }

    func updateTransport(_ transport: MultipeerTransport) {
        self.transport = transport
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastLocation = nil
        state?.isSending = false
    }

    private func handleTouches(_ touches: Set<UITouch>, event: UIEvent?) {
        guard let touch = touches.first, touch.type == .pencil || touch.type == .direct else { return }
        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in coalesced {
            sendSample(sample)
        }
    }

    private func sendSample(_ touch: UITouch) {
        let location = touch.location(in: self)
        let delta = computeDelta(from: location)
        let processed = processor?.process(delta: delta) ?? delta
        let pressureState = processor?.classifyPressure(force: touch.force) ?? .move
        let event = InputEvent(
            timestamp: touch.timestamp,
            deltaX: processed.x,
            deltaY: processed.y,
            force: touch.force,
            altitudeAngle: touch.altitudeAngle,
            azimuthAngle: touch.azimuthAngle(in: self),
            pressureState: pressureState,
            buttonDown: pressureState != .move
        )
        if let data = PacketCodec.encode(event) {
            transport?.send(data: data)
        }
        state?.lastForce = touch.force
        state?.lastState = pressureState
        state?.lastTimestamp = touch.timestamp
        state?.isSending = true
    }

    private func computeDelta(from location: CGPoint) -> SIMD2<Double> {
        defer { lastLocation = location }
        guard let lastLocation else {
            return SIMD2<Double>(0, 0)
        }
        let dx = Double(location.x - lastLocation.x)
        let dy = Double(location.y - lastLocation.y)
        return SIMD2<Double>(dx, dy)
    }
}
#endif
