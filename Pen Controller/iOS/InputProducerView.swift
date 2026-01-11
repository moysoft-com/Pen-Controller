//
//  InputProducerView.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

#if os(iOS)
import SwiftUI

final class InputProducerViewModel: ObservableObject {
    @Published var host: String = "192.168.0.2"
    @Published var port: String = "50505"
    @Published var f1: Double = 0.15
    @Published var f2: Double = 0.45
    @Published var lastState: PressureState = .move
    @Published var sentCount: Int = 0

    private let sender = UDPEventSender()
    private let filter = InputFilter()
    private var stateMachine = PressureStateMachine(f1: 0.15, f2: 0.45)

    func connect() {
        guard let portValue = UInt16(port) else { return }
        if f2 <= f1 {
            f2 = min(f1 + 0.1, 1.0)
        }
        sender.configure(host: host, port: portValue)
        stateMachine = PressureStateMachine(f1: CGFloat(f1), f2: CGFloat(f2))
    }

    func handle(sample: PencilInputView.PencilSample) {
        let state = stateMachine.state(for: sample.force)
        lastState = state
        let filtered = filter.process(delta: sample.delta, timestamp: sample.timestamp)
        let event = InputEvent(
            deltaX: filtered.x,
            deltaY: filtered.y,
            force: sample.force,
            altitudeAngle: sample.altitudeAngle,
            azimuthAngle: sample.azimuthAngle,
            timestamp: sample.timestamp,
            pressureState: state
        )
        sender.send(event: event)
        sentCount += 1
    }
}

struct InputProducerView: View {
    @StateObject private var model = InputProducerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Input Producer (iPadOS)")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                Text("Target Host")
                    .font(.caption)
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.numbersAndPunctuation)

                Text("Port")
                    .font(.caption)
                TextField("Port", text: $model.port)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                Text("Force Thresholds")
                    .font(.caption)
                HStack {
                    VStack(alignment: .leading) {
                        Text("f1 (Move → Click)")
                            .font(.caption2)
                        Slider(value: $model.f1, in: 0.05...0.6)
                    }
                    VStack(alignment: .leading) {
                        Text("f2 (Click → Drag)")
                            .font(.caption2)
                        Slider(value: $model.f2, in: 0.1...1.0)
                    }
                }
            }

            Button("Connect & Start") {
                model.connect()
            }
            .buttonStyle(.borderedProminent)

            VStack(spacing: 6) {
                Text("Last state: \(model.lastState.rawValue.capitalized)")
                Text("Sent events: \(model.sentCount)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            PencilInputView { sample in
                model.handle(sample: sample)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding()
        }
        .padding()
    }
}
#endif
