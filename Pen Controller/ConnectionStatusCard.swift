import SwiftUI

struct ConnectionStatusCard: View {
    let isConnected: Bool
    let peerName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connection")
                .font(.headline)
            
            Text("Status: " + (isConnected ? "Connected" : "Disconnected"))
                .font(.subheadline)
            
            Text("Peer: " + (isConnected && peerName != nil && !peerName!.isEmpty ? peerName! : "—"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection status card")
        .accessibilityValue(isConnected ? "Connected" : "Disconnected")
        .accessibilityHint(
            (isConnected && (peerName?.isEmpty == false))
            ? "Connected to peer \(peerName!)"
            : "Not connected to any peer"
        )
    }
}

struct ConnectionStatusCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectionStatusCard(isConnected: true, peerName: "Alice")
                .padding()
                .previewDisplayName("Connected with Peer")
            
            ConnectionStatusCard(isConnected: true, peerName: nil)
                .padding()
                .previewDisplayName("Connected without Peer")
            
            ConnectionStatusCard(isConnected: false, peerName: "Bob")
                .padding()
                .previewDisplayName("Disconnected with Peer")
            
            ConnectionStatusCard(isConnected: false, peerName: nil)
                .padding()
                .previewDisplayName("Disconnected without Peer")
        }
        .previewLayout(.sizeThatFits)
    }
}
