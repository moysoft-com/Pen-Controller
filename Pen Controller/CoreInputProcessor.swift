import Foundation

struct InputProcessingConfig {
    let forceClickThreshold: Double
    let forceDragThreshold: Double
    let smoothingFactor: Double
    let accelerationFactor: Double
    let minAcceleration: Double
    let maxAcceleration: Double
    let driftEpsilon: Double
}

final class InputProcessor {
    private let config: InputProcessingConfig
    private var filteredDelta = SIMD2<Double>(0, 0)

    init(config: InputProcessingConfig) {
        self.config = config
    }

    func process(delta: SIMD2<Double>) -> SIMD2<Double> {
        let smoothed = applySmoothing(delta: delta)
        let accelerated = applyAcceleration(delta: smoothed)
        return applyDriftCorrection(delta: accelerated)
    }

    func classifyPressure(force: Double) -> PressureState {
        if force < config.forceClickThreshold {
            return .move
        }
        if force < config.forceDragThreshold {
            return .click
        }
        return .drag
    }

    private func applySmoothing(delta: SIMD2<Double>) -> SIMD2<Double> {
        let alpha = max(0, min(1, config.smoothingFactor))
        filteredDelta = filteredDelta &* (1 - alpha) &+ delta &* alpha
        return filteredDelta
    }

    private func applyAcceleration(delta: SIMD2<Double>) -> SIMD2<Double> {
        let magnitude = sqrt(delta.x * delta.x + delta.y * delta.y)
        guard magnitude > 0 else { return delta }
        let scale = min(config.maxAcceleration, max(config.minAcceleration, 1 + magnitude * config.accelerationFactor))
        return delta &* scale
    }

    private func applyDriftCorrection(delta: SIMD2<Double>) -> SIMD2<Double> {
        if abs(delta.x) < config.driftEpsilon { return SIMD2<Double>(0, delta.y) }
        if abs(delta.y) < config.driftEpsilon { return SIMD2<Double>(delta.x, 0) }
        return delta
    }
}
