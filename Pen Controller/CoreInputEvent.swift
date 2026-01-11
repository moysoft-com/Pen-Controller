import Foundation

struct InputEvent: Codable {
    let timestamp: TimeInterval
    let deltaX: Double
    let deltaY: Double
    let force: Double
    let altitudeAngle: Double
    let azimuthAngle: Double
    let pressureState: PressureState
    let buttonDown: Bool
}

enum PressureState: String, Codable {
    case move
    case click
    case drag
}
