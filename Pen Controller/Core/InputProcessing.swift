//
//  InputProcessing.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

import CoreGraphics
import Foundation

final class PressureStateMachine {
    var f1: CGFloat
    var f2: CGFloat

    init(f1: CGFloat, f2: CGFloat) {
        self.f1 = f1
        self.f2 = f2
    }

    func state(for force: CGFloat) -> PressureState {
        if force < f1 {
            return .move
        }
        if force < f2 {
            return .click
        }
        return .drag
    }
}

final class InputFilter {
    private var lastSmoothed = CGPoint.zero
    private var lastTimestamp: TimeInterval?
    var smoothingFactor: CGFloat
    var accelerationCurve: CGFloat
    var speedThreshold: CGFloat

    init(smoothingFactor: CGFloat = 0.35, accelerationCurve: CGFloat = 0.55, speedThreshold: CGFloat = 18) {
        self.smoothingFactor = smoothingFactor
        self.accelerationCurve = accelerationCurve
        self.speedThreshold = speedThreshold
    }

    func reset() {
        lastSmoothed = .zero
        lastTimestamp = nil
    }

    func process(delta: CGPoint, timestamp: TimeInterval) -> CGPoint {
        let alpha = smoothingFactor
        lastSmoothed = CGPoint(
            x: lastSmoothed.x + alpha * (delta.x - lastSmoothed.x),
            y: lastSmoothed.y + alpha * (delta.y - lastSmoothed.y)
        )

        let dt = max(timestamp - (lastTimestamp ?? timestamp), 0.001)
        lastTimestamp = timestamp
        let speed = hypot(delta.x, delta.y) / CGFloat(dt)
        let normalizedSpeed = min(speed / speedThreshold, 3)
        let acceleration = 1 + (accelerationCurve * normalizedSpeed * normalizedSpeed)

        return CGPoint(x: lastSmoothed.x * acceleration, y: lastSmoothed.y * acceleration)
    }
}

final class RateLimiter {
    private var lastEmission: TimeInterval = 0
    let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    func allows(timestamp: TimeInterval) -> Bool {
        if timestamp - lastEmission < minimumInterval {
            return false
        }
        lastEmission = timestamp
        return true
    }
}

final class DriftCorrector {
    var deadzone: CGFloat
    var damping: CGFloat

    init(deadzone: CGFloat = 0.12, damping: CGFloat = 0.8) {
        self.deadzone = deadzone
        self.damping = damping
    }

    func apply(to delta: CGPoint) -> CGPoint {
        let magnitude = hypot(delta.x, delta.y)
        guard magnitude > deadzone else {
            return .zero
        }
        return CGPoint(x: delta.x * damping, y: delta.y * damping)
    }
}
