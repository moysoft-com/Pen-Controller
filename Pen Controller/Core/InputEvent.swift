//
//  InputEvent.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

import CoreGraphics
import Foundation

enum PressureState: String, Codable {
    case move
    case click
    case drag
}

struct InputEvent: Codable {
    let deltaX: CGFloat
    let deltaY: CGFloat
    let force: CGFloat
    let altitudeAngle: CGFloat
    let azimuthAngle: CGFloat
    let timestamp: TimeInterval
    let pressureState: PressureState
}
