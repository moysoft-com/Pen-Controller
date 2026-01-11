//
//  PencilInputView.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

#if os(iOS)
import SwiftUI
import UIKit

struct PencilInputView: UIViewRepresentable {
    final class Coordinator: NSObject {
        var onEvent: ((PencilSample) -> Void)?
        var lastPoint: CGPoint?

        init(onEvent: ((PencilSample) -> Void)?) {
            self.onEvent = onEvent
        }

        func handleTouch(_ touch: UITouch, in view: UIView) {
            guard touch.type == .pencil else { return }
            let point = touch.location(in: view)
            let previous = lastPoint ?? point
            let delta = CGPoint(x: point.x - previous.x, y: point.y - previous.y)
            lastPoint = point

            let sample = PencilSample(
                delta: delta,
                force: touch.force,
                altitudeAngle: touch.altitudeAngle,
                azimuthAngle: touch.azimuthAngle(in: view),
                timestamp: touch.timestamp
            )
            onEvent?(sample)
        }

        func reset() {
            lastPoint = nil
        }
    }

    struct PencilSample {
        let delta: CGPoint
        let force: CGFloat
        let altitudeAngle: CGFloat
        let azimuthAngle: CGFloat
        let timestamp: TimeInterval
    }

    var onEvent: ((PencilSample) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> PencilCaptureView {
        let view = PencilCaptureView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: PencilCaptureView, context: Context) {
        uiView.coordinator = context.coordinator
    }
}

final class PencilCaptureView: UIView {
    weak var coordinator: PencilInputView.Coordinator?

    override var canBecomeFirstResponder: Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { coordinator?.handleTouch($0, in: self) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { coordinator?.handleTouch($0, in: self) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { coordinator?.handleTouch($0, in: self) }
        coordinator?.reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        coordinator?.reset()
    }
}
#endif
