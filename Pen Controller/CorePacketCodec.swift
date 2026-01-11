import Foundation

enum PacketCodec {
    static func encode(_ event: InputEvent) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try? encoder.encode(event)
    }

    static func decode(_ data: Data) -> InputEvent? {
        let decoder = JSONDecoder()
        return try? decoder.decode(InputEvent.self, from: data)
    }
}
