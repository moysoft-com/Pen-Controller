import Foundation
import Network

#if os(macOS)
import SystemConfiguration

private func localComputerName() -> String {
    if let name = SCDynamicStoreCopyComputerName(nil, nil) as String? {
        return name
    }
    return ProcessInfo.processInfo.hostName
}

final class UDPServer {
    private var listener: NWListener?
    private var lastClientName: String?
    private let queue = DispatchQueue(label: "udp.server.queue", qos: .userInteractive)
    var onEvent: ((InputEvent) -> Void)?
    var onHello: ((String) -> Void)?
    private var lastClientEndpoint: NWEndpoint?

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
        // Publish a Bonjour service for discovery (optional)
        let service = NWListener.Service(name: localComputerName(), type: "_pencilinput._udp")
        listener?.service = service
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data {
                if let event = PacketCodec.decode(data) {
                    self?.onEvent?(event)
                    let name = localComputerName()
                    let ack = "ACK:\(name)"
                    connection.send(content: ack.data(using: .utf8), completion: .contentProcessed { _ in })
                } else if let text = String(data: data, encoding: .utf8), text.hasPrefix("HELLO:") {
                    // Client introduced itself; remember name
                    self?.lastClientName = String(text.dropFirst(6))
                    if let name = self?.lastClientName {
                        self?.onHello?(name)
                    }
                    let name = localComputerName()
                    let ack = "ACK:\(name)"
                    connection.send(content: ack.data(using: .utf8), completion: .contentProcessed { _ in })
                }
            }
            self?.receive(on: connection)
        }
    }
}
#else
// Non-macOS stub to satisfy cross-platform builds
final class UDPServer {
    var onEvent: ((InputEvent) -> Void)?
    func start(port: UInt16) {}
    func stop() {}
}
#endif

