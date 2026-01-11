import Foundation
import Network

final class UDPClient {
    private let connection: NWConnection
    var onAck: ((String?) -> Void)?

    init(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        connection = NWConnection(host: host, port: port, using: .udp)
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: .global(qos: .userInteractive))
        startReceiveLoop()
    }

    func send(event: InputEvent) {
        guard let data = PacketCodec.encode(event) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
    
    func send(text: String) {
        let data = text.data(using: .utf8)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func startReceiveLoop() {
        connection.receiveMessage { [weak self] data, _, _, _ in
            if let data = data, let text = String(data: data, encoding: .utf8) {
                if text == "ACK" {
                    self?.onAck?(nil)
                } else if text.hasPrefix("ACK:") {
                    let name = String(text.dropFirst(4))
                    self?.onAck?(name.isEmpty ? nil : name)
                }
            }
            // Continue receiving
            self?.startReceiveLoop()
        }
    }
}

