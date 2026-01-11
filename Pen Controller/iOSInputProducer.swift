import Foundation
import SwiftUI
import Combine

#if os(iOS)
import UIKit
import Network

final class InputProducerState: ObservableObject {
    @Published var isSending = false
    @Published var lastForce: Double = 0
    @Published var lastState: PressureState = .move
    @Published var lastTimestamp: TimeInterval = 0
    @Published var isConnected: Bool = false
    @Published var lastAck: TimeInterval = 0
    @Published var connectedPeerName: String? = nil
}

struct InputProducerView: UIViewRepresentable {
    @ObservedObject var state: InputProducerState
    let destinationHost: String
    let destinationPort: UInt16
    let config: InputProcessingConfig

    func makeUIView(context: Context) -> PencilInputView {
        let view = PencilInputView()
        view.configure(destinationHost: destinationHost, destinationPort: destinationPort, config: config, state: state)
        return view
    }

    func updateUIView(_ uiView: PencilInputView, context: Context) {
        uiView.updateConfig(config)
        uiView.updateDestination(host: destinationHost, port: destinationPort)
    }
}

final class PencilInputView: UIView {
    private var udpClient: UDPClient?
    private var processor: InputProcessor?
    private weak var state: InputProducerState?
    private var lastLocation: CGPoint?
    private var isConnected: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(destinationHost: String, destinationPort: UInt16, config: InputProcessingConfig, state: InputProducerState) {
        udpClient = UDPClient(host: .init(destinationHost), port: .init(rawValue: destinationPort) ?? 9999)
        udpClient?.onAck = { [weak self] name in
            guard let self else { return }
            self.isConnected = true
            DispatchQueue.main.async {
                self.state?.isConnected = true
                self.state?.lastAck = Date().timeIntervalSince1970
                self.state?.connectedPeerName = name
            }
        }
        processor = InputProcessor(config: config)
        self.state = state
        let deviceName = UIDevice.current.name
        udpClient?.send(text: "HELLO:\(deviceName)")
    }

    func updateConfig(_ config: InputProcessingConfig) {
        processor = InputProcessor(config: config)
    }

    func updateDestination(host: String, port: UInt16) {
        udpClient = UDPClient(host: .init(host), port: .init(rawValue: port) ?? 9999)
        self.isConnected = false
        DispatchQueue.main.async { [weak self] in
            self?.state?.isConnected = false
            self?.state?.connectedPeerName = nil
        }
        udpClient?.onAck = { [weak self] name in
            guard let self else { return }
            self.isConnected = true
            DispatchQueue.main.async {
                self.state?.isConnected = true
                self.state?.lastAck = Date().timeIntervalSince1970
                self.state?.connectedPeerName = name
            }
        }
        let deviceName = UIDevice.current.name
        udpClient?.send(text: "HELLO:\(deviceName)")
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
        udpClient?.send(event: event)
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

