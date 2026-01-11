import Foundation
import Network

final class UDPServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "udp.server.queue", qos: .userInteractive)
    var onEvent: ((InputEvent) -> Void)?

    func start(port: UInt16) {
        let port = NWEndpoint.Port(rawValue: port) ?? 9999
        do {
            listener = try NWListener(using: .udp, on: port)
        } catch {
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .global())
            self?.receive(on: connection)
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data, let event = PacketCodec.decode(data) {
                self?.onEvent?(event)
            }
            self?.receive(on: connection)
        }
    }
}
