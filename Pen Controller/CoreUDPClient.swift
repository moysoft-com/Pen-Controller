import Foundation
import Network

final class UDPClient {
    private let connection: NWConnection

    init(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        connection = NWConnection(host: host, port: port, using: .udp)
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: .global(qos: .userInteractive))
    }

    func send(event: InputEvent) {
        guard let data = PacketCodec.encode(event) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
