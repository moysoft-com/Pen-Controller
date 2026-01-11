//
//  UDPTransport.swift
//  Pen Controller
//
//  Created by OpenAI on 2025-02-11.
//

import Foundation
import Network

final class UDPEventSender: ObservableObject {
    @Published private(set) var isReady = false
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "pencontroller.udp.sender")

    func configure(host: String, port: UInt16) {
        stop()
        let endpoint = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(rawValue: port) ?? 0
        let connection = NWConnection(host: endpoint, port: port, using: .udp)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.isReady = (state == .ready)
            }
        }

        connection.start(queue: queue)
    }

    func send(event: InputEvent) {
        guard let connection else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        guard let data = try? encoder.encode(event) else { return }
        connection.send(content: data, completion: .contentProcessed({ _ in }))
    }

    func stop() {
        connection?.cancel()
        connection = nil
        isReady = false
    }
}

final class UDPEventReceiver: ObservableObject {
    @Published private(set) var isListening = false
    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private let queue = DispatchQueue(label: "pencontroller.udp.receiver")
    var onEvent: ((InputEvent) -> Void)?

    func startListening(port: UInt16) {
        stop()
        do {
            let listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port) ?? 0)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.isListening = (state == .ready)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.activeConnection = connection
                self?.receive(on: connection)
                connection.start(queue: self?.queue ?? .main)
            }
            listener.start(queue: queue)
        } catch {
            isListening = false
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data {
                let decoder = JSONDecoder()
                if let event = try? decoder.decode(InputEvent.self, from: data) {
                    DispatchQueue.main.async {
                        self?.onEvent?(event)
                    }
                }
            }
            self?.receive(on: connection)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        activeConnection?.cancel()
        activeConnection = nil
        isListening = false
    }
}
