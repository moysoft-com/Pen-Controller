import Foundation
import SwiftUI

#if os(macOS)
import AppKit
import Combine
import SystemConfiguration
import ApplicationServices

final class InputConsumerState: ObservableObject {
    @Published var lastEventTime: TimeInterval = 0
    @Published var isReceiving = false
    @Published var isConnected = false
    @Published var connectedPeerName: String? = nil
    @Published var lastPressureState: PressureState = .move
}

final class InputConsumer {
    private let server = UDPServer()
    private let processor: InputProcessor
    private var lastEventTimestamp: TimeInterval = 0
    private var lastReceiveTime = Date()
    private let minInterval: TimeInterval

    init(config: InputProcessingConfig, maxHz: Double = 240) {
        processor = InputProcessor(config: config)
        minInterval = 1 / maxHz
    }

    func start(port: UInt16, state: InputConsumerState) {
        server.onEvent = { [weak self] event in
            self?.handle(event: event, state: state)
        }
        server.onHello = { name in
            DispatchQueue.main.async {
                state.connectedPeerName = name
            }
        }
        server.start(port: port)
        state.isConnected = true
    }

    private func handle(event: InputEvent, state: InputConsumerState) {
        let now = Date()
        defer { lastReceiveTime = now }
        if now.timeIntervalSince(lastReceiveTime) > 1.0 {
            lastEventTimestamp = 0
        }
        guard event.timestamp - lastEventTimestamp >= minInterval || lastEventTimestamp == 0 else {
            return
        }
        lastEventTimestamp = event.timestamp

        let delta = SIMD2<Double>(event.deltaX, event.deltaY)
        let processed = processor.process(delta: delta)
        applyMouseMovement(delta: processed)
        applyButtonState(event: event)

        state.lastEventTime = event.timestamp
        state.isReceiving = true
        if state.connectedPeerName == nil {
            state.connectedPeerName = "iPad"
        }
        state.lastPressureState = event.pressureState
    }

    private func applyMouseMovement(delta: SIMD2<Double>) {
        guard let screen = NSScreen.main else { return }
        let location = NSEvent.mouseLocation
        let newPoint = CGPoint(
            x: min(max(location.x + delta.x, 0), screen.frame.width),
            y: min(max(location.y - delta.y, 0), screen.frame.height)
        )
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: newPoint, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    private func applyButtonState(event: InputEvent) {
        let location = NSEvent.mouseLocation
        let mouseType: CGEventType
        let button: CGMouseButton = .left

        switch event.pressureState {
        case .move:
            mouseType = .leftMouseUp
        case .click:
            mouseType = .leftMouseDown
        case .drag:
            mouseType = .leftMouseDragged
        }

        if let cgEvent = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: location, mouseButton: button) {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}

struct InputConsumerView: View {
    @StateObject private var state = InputConsumerState()
    @State private var localIPs: [String] = []
    private let consumer: InputConsumer
    private let port: UInt16

    init(config: InputProcessingConfig, port: UInt16) {
        self.consumer = InputConsumer(config: config)
        self.port = port
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Consumer (macOS)")
                .font(.title2)
            Text("Status: \(state.isReceiving ? "Receiving" : "Idle")")
            Text("Connected to: \(state.connectedPeerName ?? "—")")
            if let name = state.connectedPeerName {
                Text("Peer: \(name)")
                    .foregroundStyle(.secondary)
            }
            Text("Connection: \(state.isConnected ? "Ready" : "Not Ready")")
            Text("Last event: \(state.lastEventTime, specifier: "%.3f")")
            Text("Pressure state: \(state.lastPressureState.rawValue)")
            Text("UDP Port: \(port)")
            Text("Your IP: \(localIPs.isEmpty ? "Unknown" : localIPs.joined(separator: ", "))")
                .foregroundStyle(.secondary)
            Text("Ensure Accessibility permissions are granted.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            // Prompt user to enable Accessibility if mouse events don’t work
            if !AXIsProcessTrusted() {
                // Open System Settings Accessibility pane
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .onAppear {
            consumer.start(port: port, state: state)
            localIPs = NetworkInfo.localIPv4Addresses()
        }
    }
}

private enum NetworkInfo {
    static func localIPv4Addresses() -> [String] {
        var results: [(name: String, ip: String)] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return [] }
        defer { freeifaddrs(first) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = ptr?.pointee {
            let flags = Int32(ifa.ifa_flags)
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
               (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0 {
                var addrIn = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_in.self).pointee
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                let ipCString = inet_ntop(AF_INET, &addrIn.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                if let ipCString {
                    let ip = String(cString: ipCString)
                    let name = String(cString: ifa.ifa_name)
                    results.append((name: name, ip: ip))
                }
            }
            ptr = ifa.ifa_next
        }

        // Prefer en0 first (typical primary Ethernet/Wi‑Fi), then others
        let sorted = results.sorted { a, b in
            if a.name == "en0" && b.name != "en0" { return true }
            if b.name == "en0" && a.name != "en0" { return false }
            return a.name < b.name
        }

        var seen = Set<String>()
        var ips: [String] = []
        for item in sorted {
            if !seen.contains(item.ip) {
                seen.insert(item.ip)
                ips.append(item.ip)
            }
        }
        return ips
    }
}
#endif

